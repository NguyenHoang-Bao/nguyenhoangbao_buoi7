import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/google_api.dart';

/// Một tuyến đường được lưu vào danh sách yêu thích (một dòng trong SQLite).
class FavoriteRoute {
  final int? id; // null khi chưa lưu vào database
  final String name;
  final String startAddress;
  final String endAddress;
  final LatLng start;
  final LatLng end;
  final TravelType mode;
  final int distanceMeters;
  final int durationSeconds;
  final String polyline; // chuỗi encoded polyline -> vẽ lại không cần gọi API
  final String createdAt;

  FavoriteRoute({
    this.id,
    required this.name,
    required this.startAddress,
    required this.endAddress,
    required this.start,
    required this.end,
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'start_address': startAddress,
        'end_address': endAddress,
        'start_lat': start.latitude,
        'start_lng': start.longitude,
        'end_lat': end.latitude,
        'end_lng': end.longitude,
        'mode': mode.apiValue,
        'distance_m': distanceMeters,
        'duration_s': durationSeconds,
        'polyline': polyline,
        'created_at': createdAt,
      };

  factory FavoriteRoute.fromMap(Map<String, Object?> m) => FavoriteRoute(
        id: m['id'] as int?,
        name: m['name'] as String,
        startAddress: m['start_address'] as String,
        endAddress: m['end_address'] as String,
        start: LatLng(
            (m['start_lat'] as num).toDouble(), (m['start_lng'] as num).toDouble()),
        end: LatLng(
            (m['end_lat'] as num).toDouble(), (m['end_lng'] as num).toDouble()),
        mode: TravelType.fromApi(m['mode'] as String),
        distanceMeters: m['distance_m'] as int,
        durationSeconds: m['duration_s'] as int,
        polyline: m['polyline'] as String,
        createdAt: m['created_at'] as String?,
      );

  RouteResult toRouteResult() => RouteResult(
        encodedPolyline: polyline,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
}
