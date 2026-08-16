import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/landmark.dart';

/// Thrown for any non-2xx response or malformed payload from the API.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper around the single faculty-provided endpoint:
/// https://labs.anontech.info/cse489/exm3/api.php
///
/// IMPORTANT: per the exam rules, this app never builds or modifies a
/// backend of its own -- every network call in this class hits the
/// provided API only.
class ApiService {
  // Student ID used as the API key, per exam instructions.
  static const String apiKey = '22299059';
  static const String _base = 'https://labs.anontech.info/cse489/exm3/api.php';

  Uri _uri(String action, [Map<String, String>? extra]) {
    final params = <String, String>{'action': action, 'key': apiKey, ...?extra};
    return Uri.parse(_base).replace(queryParameters: params);
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 403) {
      throw ApiException('Invalid or expired API key.', statusCode: 403);
    }
    if (res.statusCode == 404) {
      throw ApiException('Not found.', statusCode: 404);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Server error (${res.statusCode}).', statusCode: res.statusCode);
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'list': decoded};
      throw ApiException('Unexpected response shape.');
    } on FormatException {
      throw ApiException('Malformed JSON from server.');
    }
  }

  /// GET ?action=get_landmarks&key=KEY
  Future<List<Landmark>> getLandmarks() async {
    final res = await http.get(_uri('get_landmarks')).timeout(const Duration(seconds: 20));
    final body = _decode(res);
    final list = (body['landmarks'] ?? body['list'] ?? body['data'] ?? body['value'] ?? []) as List;
    return list
        .whereType<Map>()
        .map((e) => Landmark.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST ?action=visit_landmark&key=KEY
  /// Body: {landmark_id, user_lat, user_lon}
  /// Returns immediately with {job_id, status: "pending"} -- the actual
  /// distance is NOT available yet and must be polled via get_job_status.
  Future<int> submitVisit({
    required int landmarkId,
    required double userLat,
    required double userLon,
  }) async {
    final res = await http
        .post(
          _uri('visit_landmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'landmark_id': landmarkId,
            'user_lat': userLat,
            'user_lon': userLon,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(res);
    final jobId = body['job_id'];
    if (jobId == null) {
      throw ApiException('Server did not return a job_id for the visit.');
    }
    return jobId is int ? jobId : int.parse(jobId.toString());
  }

  /// GET ?action=get_job_status&key=KEY&job_id=ID
  /// Returns {job_id, status} while pending, and additionally {distance}
  /// once status == 'done'. Callers must poll -- never assume it's ready.
  Future<JobStatusResult> getJobStatus(int jobId) async {
    final res = await http
        .get(_uri('get_job_status', {'job_id': jobId.toString()}))
        .timeout(const Duration(seconds: 20));
    final body = _decode(res);
    return JobStatusResult(
      jobId: jobId,
      status: (body['status'] ?? 'pending').toString(),
      distance: body['distance'] == null ? null : (body['distance'] as num).toDouble(),
    );
  }

  /// POST ?action=create_landmark&key=KEY (multipart/form-data)
  /// Per the exam sheet's "Most Common mistakes" note: raw JSON leaves
  /// $_FILES empty server-side, so this MUST be form-data, not JSON.
  Future<Landmark> createLandmark({
    required String title,
    required double lat,
    required double lon,
    File? imageFile,
  }) async {
    final request = http.MultipartRequest('POST', _uri('create_landmark'));
    request.fields['title'] = title;
    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);
    final landmarkJson = body['landmark'] ?? body;
    return Landmark.fromJson(Map<String, dynamic>.from(landmarkJson));
  }

  /// POST ?action=delete_landmark&key=KEY  Body: {landmark_id}
  Future<void> deleteLandmark(int landmarkId) async {
    final res = await http
        .post(
          _uri('delete_landmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'landmark_id': landmarkId}),
        )
        .timeout(const Duration(seconds: 20));
    _decode(res);
  }

  /// POST ?action=restore_landmark&key=KEY  Body: {landmark_id}
  Future<void> restoreLandmark(int landmarkId) async {
    final res = await http
        .post(
          _uri('restore_landmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'landmark_id': landmarkId}),
        )
        .timeout(const Duration(seconds: 20));
    _decode(res);
  }
}

class JobStatusResult {
  final int jobId;
  final String status; // 'pending' | 'done'
  final double? distance;
  JobStatusResult({required this.jobId, required this.status, required this.distance});
  bool get isDone => status == 'done';
}
