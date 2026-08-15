/// A completed visit, shown on the Activity screen.
class Visit {
  final int? localId;
  final int landmarkId;
  final String landmarkTitle;
  final DateTime visitTime;
  final double? distance; // null while still pending
  final String status; // 'pending' | 'done' | 'failed'

  Visit({
    this.localId,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.visitTime,
    required this.distance,
    required this.status,
  });

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      localId: map['id'] as int?,
      landmarkId: map['landmarkId'] as int,
      landmarkTitle: map['landmarkTitle'] as String,
      visitTime: DateTime.fromMillisecondsSinceEpoch(map['visitTime'] as int),
      distance: map['distance'] == null ? null : (map['distance'] as num).toDouble(),
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (localId != null) 'id': localId,
      'landmarkId': landmarkId,
      'landmarkTitle': landmarkTitle,
      'visitTime': visitTime.millisecondsSinceEpoch,
      'distance': distance,
      'status': status,
    };
  }
}

/// A visit job that has been submitted to the server and is awaiting
/// get_job_status to report 'done'. Persisted so WorkManager can resume
/// polling even after the app process dies/restarts.
class PendingJob {
  final int localId;
  final int jobId;
  final int landmarkId;
  final String landmarkTitle;
  final DateTime createdAt;

  PendingJob({
    required this.localId,
    required this.jobId,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.createdAt,
  });

  factory PendingJob.fromMap(Map<String, dynamic> map) {
    return PendingJob(
      localId: map['id'] as int,
      jobId: map['jobId'] as int,
      landmarkId: map['landmarkId'] as int,
      landmarkTitle: map['landmarkTitle'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'landmarkId': landmarkId,
      'landmarkTitle': landmarkTitle,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// A visit request made while offline (or one that failed to submit).
/// Queued locally and drained by WorkManager once connectivity returns.
class QueuedVisit {
  final int? localId;
  final int landmarkId;
  final String landmarkTitle;
  final double userLat;
  final double userLon;
  final DateTime queuedAt;
  final int attempts;

  QueuedVisit({
    this.localId,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.userLat,
    required this.userLon,
    required this.queuedAt,
    this.attempts = 0,
  });

  factory QueuedVisit.fromMap(Map<String, dynamic> map) {
    return QueuedVisit(
      localId: map['id'] as int?,
      landmarkId: map['landmarkId'] as int,
      landmarkTitle: map['landmarkTitle'] as String,
      userLat: (map['userLat'] as num).toDouble(),
      userLon: (map['userLon'] as num).toDouble(),
      queuedAt: DateTime.fromMillisecondsSinceEpoch(map['queuedAt'] as int),
      attempts: map['attempts'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (localId != null) 'id': localId,
      'landmarkId': landmarkId,
      'landmarkTitle': landmarkTitle,
      'userLat': userLat,
      'userLon': userLon,
      'queuedAt': queuedAt.millisecondsSinceEpoch,
      'attempts': attempts,
    };
  }
}
