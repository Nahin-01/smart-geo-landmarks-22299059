import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import '../models/visit.dart';

const String kPeriodicSyncTask = 'smart_landmarks_periodic_sync';
const String kOneOffPollTask = 'smart_landmarks_poll_job';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case kOneOffPollTask:
          final jobId = inputData?['jobId'] as int?;
          if (jobId != null) {
            await BackgroundSyncRunner.pollSingleJob(jobId);
          }
          await BackgroundSyncRunner.runFullSync();
          break;
        case kPeriodicSyncTask:
        default:
          await BackgroundSyncRunner.runFullSync();
          break;
      }
      return Future.value(true);
    } catch (_) {
      // Returning false tells WorkManager to retry with backoff.
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    
    await Workmanager().registerPeriodicTask(
      kPeriodicSyncTask,
      kPeriodicSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  
  static Future<void> scheduleImmediatePoll(int jobId) async {
    await Workmanager().registerOneOffTask(
      '${kOneOffPollTask}_$jobId',
      kOneOffPollTask,
      inputData: {'jobId': jobId},
      initialDelay: const Duration(seconds: 3),
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 10),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}

/// The actual sync logic, factored out so it can be called both from the
/// WorkManager background isolate and (for a snappier UI) from the
/// foreground when the app is active.
class BackgroundSyncRunner {
  static final ApiService _api = ApiService();
  static final DatabaseService _db = DatabaseService.instance;
  static final ConnectivityService _connectivity = ConnectivityService();

  static Future<void> runFullSync() async {
    if (!await _connectivity.isOnline()) return;
    await drainOfflineQueue();
    await pollAllPendingJobs();
  }

  /// Requirement 8: sync queued (offline-submitted) visit requests once
  /// connectivity is available, with retry/backoff on failure.
  static Future<void> drainOfflineQueue() async {
    final queued = await _db.getQueuedVisits();
    for (final qv in queued) {
      try {
        final jobId = await _api.submitVisit(
          landmarkId: qv.landmarkId,
          userLat: qv.userLat,
          userLon: qv.userLon,
        );
        await _db.insertPendingJob(PendingJob(
          localId: 0,
          jobId: jobId,
          landmarkId: qv.landmarkId,
          landmarkTitle: qv.landmarkTitle,
          createdAt: DateTime.now(),
        ));
        await _db.insertVisit(Visit(
          landmarkId: qv.landmarkId,
          landmarkTitle: qv.landmarkTitle,
          visitTime: DateTime.now(),
          distance: null,
          status: 'pending',
        ));
        if (qv.localId != null) await _db.removeQueuedVisit(qv.localId!);
      } catch (_) {
        // Leave it queued; bump attempts for basic backoff/observability.
        if (qv.localId != null) {
          await _db.bumpQueuedVisitAttempts(qv.localId!, qv.attempts + 1);
        }
      }
    }
  }

  /// Requirement 10.1: poll get_job_status for pending visit job(s) until
  /// they resolve, then write the result into the local cache/history.
  static Future<void> pollAllPendingJobs() async {
    final jobs = await _db.getPendingJobs();
    for (final job in jobs) {
      await _pollAndApply(job);
    }
  }

  static Future<void> pollSingleJob(int jobId) async {
    final jobs = await _db.getPendingJobs();
    final match = jobs.where((j) => j.jobId == jobId);
    if (match.isEmpty) return;
    await _pollAndApply(match.first);
  }

  static Future<void> _pollAndApply(PendingJob job) async {
    try {
      final result = await _api.getJobStatus(job.jobId);
      if (!result.isDone) return; // still pending, try again next cycle
      final distance = result.distance ?? 0.0;
      await _db.updateLandmarkAfterVisit(job.landmarkId, distance);
      await _markMatchingVisitDone(job.landmarkId, distance);
      await _db.removePendingJob(job.localId);
    } catch (_) {
      // Network hiccup or job_not_found -- leave it for the next attempt.
    }
  }

  static Future<void> _markMatchingVisitDone(int landmarkId, double distance) async {
    final history = await _db.getVisitHistory();
    final pendingEntry = history.firstWhere(
      (v) => v.landmarkId == landmarkId && v.status == 'pending',
      orElse: () => Visit(
        landmarkId: landmarkId,
        landmarkTitle: '',
        visitTime: DateTime.now(),
        distance: null,
        status: 'none',
      ),
    );
    if (pendingEntry.localId != null) {
      await _db.updateVisitStatus(pendingEntry.localId!, distance: distance, status: 'done');
    }
  }
}
