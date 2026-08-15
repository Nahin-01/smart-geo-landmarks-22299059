import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/landmark.dart';
import '../models/visit.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/connectivity_service.dart';
import '../services/background_service.dart';

enum SortMode { scoreHighToLow, scoreLowToHigh }

/// Repository-pattern app state: Room/sqflite (via DatabaseService) is the
/// single source of truth. The API is only ever hit to refresh that cache
/// or to push a change; every screen reads from this provider, which in
/// turn reads from the local DB -- so the UI keeps working offline.
class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService.instance;
  final LocationService _location = LocationService();
  final ConnectivityService _connectivity = ConnectivityService();

  List<Landmark> landmarks = []; // non-deleted, from cache
  List<Landmark> allLandmarksIncludingDeleted = [];
  List<Visit> visitHistory = [];

  bool isLoading = false;
  bool isOnline = true;
  String? lastError;

  double minScoreFilter = 0;
  SortMode sortMode = SortMode.scoreHighToLow;

  Timer? _foregroundPollTimer;
  StreamSubscription<bool>? _connSub;

  Future<void> init() async {
    isOnline = await _connectivity.isOnline();
    _connSub = _connectivity.onStatusChange.listen((online) {
      final wasOffline = !isOnline;
      isOnline = online;
      notifyListeners();
      if (online && wasOffline) {
        // Requirement 8: sync queued requests as soon as internet is back.
        syncNow();
      }
    });

    await loadFromCache();
    await refreshFromServer();
    _startForegroundPolling();
  }

  Future<void> loadFromCache() async {
    landmarks = await _db.getCachedLandmarks();
    allLandmarksIncludingDeleted = await _db.getCachedLandmarks(includeDeleted: true);
    visitHistory = await _db.getVisitHistory();
    notifyListeners();
  }

  /// Fetch fresh data from the API and write it through to the local
  /// cache. Safe to call while offline -- it will simply fail quietly and
  /// the UI keeps showing whatever was last cached.
  Future<void> refreshFromServer() async {
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      final fresh = await _api.getLandmarks();
      await _db.upsertLandmarksFromServer(fresh);
      isOnline = true;
    } catch (e) {
      isOnline = false;
      lastError = e.toString();
    } finally {
      await loadFromCache();
      isLoading = false;
      notifyListeners();
    }
  }

  List<Landmark> get filteredSortedLandmarks {
    var list = landmarks.where((l) => l.score >= minScoreFilter).toList();
    list.sort((a, b) => sortMode == SortMode.scoreHighToLow
        ? b.score.compareTo(a.score)
        : a.score.compareTo(b.score));
    return list;
  }

  void setMinScoreFilter(double value) {
    minScoreFilter = value;
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    sortMode = mode;
    notifyListeners();
  }

  // ---------------- Visit flow ----------------

  /// Gets GPS location, then either submits the visit immediately (online)
  /// or queues it for later (offline). Returns a status string for the UI
  /// to show via Toast/Snackbar.
  Future<String> visitLandmark(Landmark landmark) async {
    final position = await _location.getCurrentLocation();

    final online = await _connectivity.isOnline();
    if (!online) {
      await _db.enqueueVisit(QueuedVisit(
        landmarkId: landmark.id,
        landmarkTitle: landmark.title,
        userLat: position.latitude,
        userLon: position.longitude,
        queuedAt: DateTime.now(),
      ));
      await loadFromCache();
      return 'Offline: visit to "${landmark.title}" queued and will sync automatically.';
    }

    try {
      final jobId = await _api.submitVisit(
        landmarkId: landmark.id,
        userLat: position.latitude,
        userLon: position.longitude,
      );
      await _db.insertPendingJob(PendingJob(
        localId: 0,
        jobId: jobId,
        landmarkId: landmark.id,
        landmarkTitle: landmark.title,
        createdAt: DateTime.now(),
      ));
      await _db.insertVisit(Visit(
        landmarkId: landmark.id,
        landmarkTitle: landmark.title,
        visitTime: DateTime.now(),
        distance: null,
        status: 'pending',
      ));
      await loadFromCache();
      // Guarantee the poll survives even if the app is backgrounded now.
      await BackgroundService.scheduleImmediatePoll(jobId);
      return 'Visit submitted (job #$jobId). Distance will appear shortly.';
    } catch (e) {
      // Submission itself failed (e.g. flaky connection) -- queue it so
      // it isn't lost, matching the offline-queue/retry requirement.
      await _db.enqueueVisit(QueuedVisit(
        landmarkId: landmark.id,
        landmarkTitle: landmark.title,
        userLat: position.latitude,
        userLon: position.longitude,
        queuedAt: DateTime.now(),
      ));
      await loadFromCache();
      return 'Could not reach server, visit queued for retry. (${e.toString()})';
    }
  }

  /// While the app is open, poll a bit faster than the 15-minute
  /// WorkManager minimum so the UI feels responsive. WorkManager (see
  /// background_service.dart) is what guarantees this still happens when
  /// the app is closed or killed.
  void _startForegroundPolling() {
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!await _connectivity.isOnline()) return;
      await BackgroundSyncRunner.runFullSync();
      await loadFromCache();
    });
  }

  Future<void> syncNow() async {
    await BackgroundSyncRunner.runFullSync();
    await loadFromCache();
    await refreshFromServer();
  }

  // ---------------- Create / delete / restore ----------------

  Future<void> addLandmark({
    required String title,
    required double lat,
    required double lon,
    File? image,
  }) async {
    final created = await _api.createLandmark(title: title, lat: lat, lon: lon, imageFile: image);
    await _db.upsertLandmarksFromServer([created]);
    await loadFromCache();
  }

  Future<void> deleteLandmark(Landmark landmark) async {
    try {
      await _api.deleteLandmark(landmark.id);
    } finally {
      // Reflect it locally regardless, so the UI is consistent even if the
      // request is still in flight / the app goes offline right after.
      await _db.markDeletedLocally(landmark.id, true);
      await loadFromCache();
    }
  }

  Future<void> restoreLandmark(Landmark landmark) async {
    try {
      await _api.restoreLandmark(landmark.id);
    } finally {
      await _db.markDeletedLocally(landmark.id, false);
      await loadFromCache();
    }
  }

  @override
  void dispose() {
    _foregroundPollTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
