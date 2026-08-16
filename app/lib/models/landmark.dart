
class Landmark {
  final int id;
  final String title;
  final double lat;
  final double lon;
  final String? image;
  final double score;
  final int visitCount;
  final double? avgDistance;
  final bool isDeleted;

  Landmark({
    required this.id,
    required this.title,
    required this.lat,
    required this.lon,
    required this.image,
    required this.score,
    required this.visitCount,
    required this.avgDistance,
    this.isDeleted = false,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: _asInt(json['id']),
      title: (json['title'] ?? 'Untitled').toString(),
      lat: _asDouble(json['lat']),
      lon: _asDouble(json['lon']),
      image: json['image']?.toString(),
      score: _asDouble(json['score']),
      visitCount: _asInt(json['visit_count'] ?? 0),
      avgDistance:
          json['avg_distance'] == null ? null : _asDouble(json['avg_distance']),
    );
  }

  factory Landmark.fromMap(Map<String, dynamic> map) {
    return Landmark(
      id: _asInt(map['id']),
      title: map['title'] as String,
      lat: _asDouble(map['lat']),
      lon: _asDouble(map['lon']),
      image: map['image'] as String?,
      score: _asDouble(map['score']),
      visitCount: _asInt(map['visitCount'] ?? 0),
      avgDistance: map['avgDistance'] == null ? null : _asDouble(map['avgDistance']),
      isDeleted: (map['isDeleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'lat': lat,
      'lon': lon,
      'image': image,
      'score': score,
      'visitCount': visitCount,
      'avgDistance': avgDistance,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  Landmark copyWith({bool? isDeleted, int? visitCount, double? avgDistance}) {
    return Landmark(
      id: id,
      title: title,
      lat: lat,
      lon: lon,
      image: image,
      score: score,
      visitCount: visitCount ?? this.visitCount,
      avgDistance: avgDistance ?? this.avgDistance,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
