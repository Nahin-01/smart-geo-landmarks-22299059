CSE 489: Mobile Application Development
Lab Exam — Smart Geo-Tagged Landmarks (v5)
Student ID: 22299059
Built with: Flutter / Dart

================================================================
1. PROJECT OVERVIEW
================================================================
Smart Geo-Tagged Landmarks is a Flutter (Dart) Android application that
consumes the faculty-provided REST API at
https://labs.anontech.info/cse489/exm3/api.php (key=22299059) to let a
user browse, visit, filter, add, and soft-delete geo-tagged landmarks
across Bangladesh, fully offline-capable. No backend of any kind was
built or modified — every write/read goes through the provided endpoints
only.

================================================================
2. FEATURES IMPLEMENTED
================================================================
- Bottom Navigation with 4 tabs: Map, Landmarks, Activity, Add/View.

- Map tab: OpenStreetMap tiles (flutter_map) centered on Bangladesh
  (23.685, 90.3563). One marker per landmark; marker color runs
  red -> amber -> green as score goes low -> high. Tapping a marker opens
  a detail sheet with title, score, visit count, avg distance and a
  "Visit this landmark" action.

- Landmarks tab: full list with title, image thumbnail, and score badge.
  Supports sorting (score high->low / low->high) and a minimum-score
  filter slider. Pull-to-refresh re-syncs with the server.

- Visit feature: fetches current GPS location (geolocator), POSTs
  visit_landmark, receives a job_id immediately (status "pending"), and
  polls get_job_status in the background (via WorkManager — see below)
  until status becomes "done", at which point the returned distance is
  written into visit history and the landmark's average distance /
  visit count. A foreground timer additionally polls every few seconds
  while the app is open, purely so the UI feels fast; WorkManager is what
  guarantees the poll survives the app being backgrounded or killed.

- Activity tab: chronological visit history (landmark name, visit time,
  distance), including entries still shown as "Pending..." until their
  job resolves, and a manual "Sync now" action.

- Add/View tab:
  * "Add New" sub-tab: title, latitude/longitude (with a one-tap
    "Auto-fetch current GPS location" button), and an image picker
    (Android Photo Picker via image_picker). Submits as multipart
    form-data (NOT raw JSON) specifically because the exam sheet notes
    $_FILES is empty server-side for raw JSON uploads.
  * "Manage" sub-tab: lists every landmark (including locally-known
    soft-deleted ones) with a Delete button, or a Restore button for
    already-deleted items.

- Soft delete handling: deleting calls delete_landmark and flips a
  local-only isDeleted flag so the item disappears from the Map/
  Landmarks/visit flow immediately, without losing the record needed to
  restore it later (the server itself simply stops returning deleted
  items from get_landmarks, so this local flag is what lets "Manage"
  keep offering Restore). The app does not crash if a landmark
  disappears or reappears between refreshes — all list rendering is
  null/empty-safe.

- Offline support (see section 4 below).

- Error handling: SnackBars for success/info messages (visit submitted,
  landmark created, sync complete), AlertDialogs for hard failures
  (landmark creation failed, invalid key, etc.), and every API/DB/GPS
  call is wrapped in try/catch so a flaky network or missing permission
  never crashes the app.

================================================================
3. API USAGE
================================================================
All access goes through lib/services/api_service.dart, one method per
endpoint:
  GET  ?action=get_landmarks&key=22299059
  POST ?action=visit_landmark&key=22299059       (JSON body)
  GET  ?action=get_job_status&key=22299059&job_id=...
  POST ?action=create_landmark&key=22299059      (multipart/form-data)
  POST ?action=delete_landmark&key=22299059      (JSON body: landmark_id)
  POST ?action=restore_landmark&key=22299059     (JSON body: landmark_id)
A 403 response is treated as an invalid/expired key and surfaced as a
readable error rather than a crash.

================================================================
4. OFFLINE STRATEGY
================================================================
Architecture: Repository pattern / single source of truth, using SQLite
(sqflite) as the local "Room" equivalent (lib/services/database_service.dart):
  - `landmarks`      cached copy of every landmark ever seen, plus a
                      local isDeleted flag (see above).
  - `visits`          completed/failed/pending visit history.
  - `pending_jobs`     visit jobs awaiting a "done" get_job_status result.
  - `queued_visits`    visit requests made while offline.

All four screens read only from this local database via AppState
(ChangeNotifier) — never directly from the network — so the UI keeps
working (map, list, activity, manage) with the last-cached data when
there is no connection.

When the user taps "Visit":
  - If online: submit immediately, store the job_id in `pending_jobs`,
    add a "pending" row to `visits`, and schedule a WorkManager one-off
    task to poll it.
  - If offline (or the submit call itself fails): the visit is written
    into `queued_visits` instead, and the UI tells the user it will sync
    automatically.

connectivity_plus watches for connectivity changes; the moment the
device comes back online, AppState automatically drains the offline
queue and re-syncs with the server.

================================================================
5. ARCHITECTURE USED
================================================================
- Repository pattern: DatabaseService is the single source of truth;
  ApiService only ever writes through it, UI only ever reads from it
  (via the AppState ChangeNotifier that screens `watch`/`read` through
  the `provider` package).
- Background work: WorkManager (via the `workmanager` plugin) drives one
  periodic task (every 15 minutes — Android's WorkManager minimum) that
  both (a) polls any still-pending visit jobs and (b) drains the offline
  visit queue with exponential backoff, plus a one-off task fired
  immediately after each visit submission for a faster real-world
  response time. This satisfies the "one WorkManager-based mechanism
  should reasonably serve both" guidance in the exam sheet, and is not a
  manual Thread/Timer loop for the guaranteed/background-safe part.
- Screens: lib/screens/ (map, landmarks, activity, add_view,
  main_navigation) are presentation-only; all logic lives in
  lib/providers/app_state.dart and lib/services/.

================================================================
6. CHALLENGES FACED
================================================================
- Asynchronous visit flow: the server intentionally does not return the
  distance from visit_landmark itself, only a job_id. The trickiest part
  was making sure the UI never assumes the result is ready, while still
  feeling responsive — solved with a fast foreground poll for UX plus a
  WorkManager-guaranteed background poll for correctness/reliability.
- WorkManager's real Android minimum periodic interval is 15 minutes,
  which is too slow for "a few seconds" turnaround on its own — worked
  around by pairing it with an immediate one-off WorkManager task per
  visit (and a lightweight foreground timer while the app is open).
- Reconciling soft deletes: the API's get_landmarks simply omits deleted
  landmarks rather than flagging them, so the app has to remember
  deletions locally (rather than derive them from the server response)
  in order to still offer "Restore" in the Manage tab.
- Avoiding crashes on changing/soft-deleted data: all list/map rendering
  reads from the local cache and treats missing images, null avg
  distance, and landmarks that vanish between refreshes as normal,
  expected states rather than errors.

================================================================
7. HOW TO BUILD (SETUP NOTES — not part of the graded README content,
   included for convenience)
================================================================
This submission ships the full Dart/Flutter source (lib/), pubspec.yaml,
and the AndroidManifest.xml permissions block. To get a buildable Flutter
project shell around it (gradle wrapper, ios/ folder, etc. are
environment-specific and are intentionally not hand-written):

  1. flutter create --org com.cse489 --project-name smart_landmarks .
     (run inside the app/ folder; say yes to overwriting when prompted
     for android/app/src/main/AndroidManifest.xml, or manually merge the
     permissions from the one provided here)
  2. Overwrite pubspec.yaml and lib/ with the ones in this submission.
  3. flutter pub get
  4. flutter run
