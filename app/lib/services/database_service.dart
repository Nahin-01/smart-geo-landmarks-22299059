import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/landmark.dart';
import '../models/visit.dart';

/// Local single-source-of-truth database (Repository pattern).
///
/// - `landmarks`      : cached copy of everything the server has told us
///                       about, including a local-only isDeleted flag so
///                       soft-deleted landmarks can still be restored.
/// - `visits`          : completed (or failed) visit history entries.
/// - `pending_jobs`     : visit jobs submitted to the server whose
///                       get_job_status result hasn't come back as 'done'
///                       yet. Survives app restarts so WorkManager can
///                       resume polling.
/// - `queued_visits`    : visit requests made while offline, waiting to be
///                       resent once connectivity returns.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_landmarks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE landmarks (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            image TEXT,
            score REAL NOT NULL,
            visitCount INTEGER NOT NULL DEFAULT 0,
            avgDistance REAL,
            isDeleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            landmarkId INTEGER NOT NULL,
            landmarkTitle TEXT NOT NULL,
            visitTime INTEGER NOT NULL,
            distance REAL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            jobId INTEGER NOT NULL,
            landmarkId INTEGER NOT NULL,
            landmarkTitle TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE queued_visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            landmarkId INTEGER NOT NULL,
            landmarkTitle TEXT NOT NULL,
            userLat REAL NOT NULL,
            userLon REAL NOT NULL,
            queuedAt INTEGER NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // ---------------- Landmarks (cache) ----------------

  /// Merge a fresh server list into the cache. Anything currently marked
  /// isDeleted locally that the server no longer returns stays as-is
  /// (still deleted, still restorable). Anything the server DOES return
  /// is written through as the source of truth for its fields, and its
  /// isDeleted flag is cleared (a restore may have happened elsewhere).
  Future<void> upsertLandmarksFromServer(List<Landmark> serverLandmarks) async {
    final db = await database;
    final batch = db.batch();
    for (final l in serverLandmarks) {
      batch.insert(
        'landmarks',
        l.copyWith(isDeleted: false).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Landmark>> getCachedLandmarks({bool includeDeleted = false}) async {
    final db = await database;
    final rows = await db.query(
      'landmarks',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'score DESC',
    );
    return rows.map((e) => Landmark.fromMap(e)).toList();
  }

  Future<void> markDeletedLocally(int landmarkId, bool deleted) async {
    final db = await database;
    await db.update(
      'landmarks',
      {'isDeleted': deleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [landmarkId],
    );
  }

  Future<void> updateLandmarkAfterVisit(int landmarkId, double distance) async {
    final db = await database;
    final rows = await db.query('landmarks', where: 'id = ?', whereArgs: [landmarkId]);
    if (rows.isEmpty) return;
    final current = Landmark.fromMap(rows.first);
    final newCount = current.visitCount + 1;
    final prevAvg = current.avgDistance ?? distance;
    final newAvg = ((prevAvg * current.visitCount) + distance) / newCount;
    await db.update(
      'landmarks',
      {'visitCount': newCount, 'avgDistance': newAvg},
      where: 'id = ?',
      whereArgs: [landmarkId],
    );
  }

  // ---------------- Visit history ----------------

  Future<int> insertVisit(Visit visit) async {
    final db = await database;
    return db.insert('visits', visit.toMap());
  }

  Future<void> updateVisitStatus(int localId, {double? distance, required String status}) async {
    final db = await database;
    await db.update(
      'visits',
      {'distance': distance, 'status': status},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Visit>> getVisitHistory() async {
    final db = await database;
    final rows = await db.query('visits', orderBy: 'visitTime DESC');
    return rows.map((e) => Visit.fromMap(e)).toList();
  }

  // ---------------- Pending jobs (async polling) ----------------

  Future<int> insertPendingJob(PendingJob job) async {
    final db = await database;
    return db.insert('pending_jobs', job.toMap());
  }

  Future<List<PendingJob>> getPendingJobs() async {
    final db = await database;
    final rows = await db.query('pending_jobs');
    return rows.map((e) => PendingJob.fromMap(e)).toList();
  }

  Future<void> removePendingJob(int localId) async {
    final db = await database;
    await db.delete('pending_jobs', where: 'id = ?', whereArgs: [localId]);
  }

  // ---------------- Offline visit queue ----------------

  Future<int> enqueueVisit(QueuedVisit qv) async {
    final db = await database;
    return db.insert('queued_visits', qv.toMap());
  }

  Future<List<QueuedVisit>> getQueuedVisits() async {
    final db = await database;
    final rows = await db.query('queued_visits', orderBy: 'queuedAt ASC');
    return rows.map((e) => QueuedVisit.fromMap(e)).toList();
  }

  Future<void> removeQueuedVisit(int localId) async {
    final db = await database;
    await db.delete('queued_visits', where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> bumpQueuedVisitAttempts(int localId, int attempts) async {
    final db = await database;
    await db.update(
      'queued_visits',
      {'attempts': attempts},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}
