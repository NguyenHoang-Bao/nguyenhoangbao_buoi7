import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Lỗi có thông điệp tiếng Việt để hiện lên SnackBar.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Phương tiện di chuyển (giá trị apiValue là chuỗi Routes API yêu cầu).
enum TravelType {
  drive('DRIVE', 'Ô tô'),
  twoWheeler('TWO_WHEELER', 'Xe máy'),
  walk('WALK', 'Đi bộ'),
  bicycle('BICYCLE', 'Xe đạp');

  final String apiValue;
  final String label;
  const TravelType(this.apiValue, this.label);

  static TravelType fromApi(String v) => TravelType.values.firstWhere(
        (t) => t.apiValue == v,
        orElse: () => TravelType.drive,
      );
}

String formatDistance(int meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '$meters m';

String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes phút';
  return '${minutes ~/ 60} giờ ${minutes % 60} phút';
}

/// Một tuyến đường do Routes API trả về.
class RouteResult {
  final String encodedPolyline;
  final int distanceMeters;
  final int durationSeconds;

  RouteResult({
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Danh sách điểm vẽ Polyline (giải mã từ chuỗi encodedPolyline).
  late final List<LatLng> points = decodePolyline(encodedPolyline);

  String get distanceText => formatDistance(distanceMeters);
  String get durationText => formatDuration(durationSeconds);
}

/// Kết quả Geocoding: địa chỉ -> tọa độ.
class GeocodeResult {
  final LatLng location;
  final String formattedAddress;
  GeocodeResult(this.location, this.formattedAddress);
}

/// Một địa điểm tìm được từ Places API.
class PlaceItem {
  final String name;
  final String address;
  final LatLng location;
  PlaceItem(this.name, this.address, this.location);
}

class GoogleApi {
  static void _ensureKey() {
    if (!hasApiKey) {
      throw ApiException(
          'Chưa cấu hình API key! Mở lib/config.dart và dán key của bạn.');
    }
  }

  static String _errorFrom(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final m = d['error']?['message'];
      if (m is String) return 'Lỗi ${r.statusCode}: $m';
    } catch (_) {}
    return 'Lỗi khi gọi API: ${r.statusCode}';
  }

  static Map<String, dynamic> _latLngJson(LatLng p) => {
        'location': {
          'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
        },
      };

  /// Tìm đường đi bằng Routes API (thay cho Directions API cũ).
  /// - [alternatives] = true: lấy thêm các tuyến thay thế.
  static Future<List<RouteResult>> computeRoutes({
    required LatLng origin,
    required LatLng destination,
    TravelType mode = TravelType.drive,
    bool alternatives = false,
  }) async {
    _ensureKey();

    Future<http.Response> send(bool alt) {
      final body = <String, dynamic>{
        'origin': _latLngJson(origin),
        'destination': _latLngJson(destination),
        'travelMode': mode.apiValue,
        // routingPreference chỉ dùng được với ô tô
        if (mode == TravelType.drive) 'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': alt,
        'languageCode': 'vi-VN',
        'units': 'METRIC',
      };
      return http.post(
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'X-Goog-Api-Key': kApiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: jsonEncode(body),
      );
    }

    var res = await send(alternatives);
    // Một số phương tiện không hỗ trợ tuyến thay thế -> thử lại không có.
    if (res.statusCode != 200 && alternatives) {
      res = await send(false);
    }
    if (res.statusCode != 200) throw ApiException(_errorFrom(res));

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) throw ApiException('Không tìm thấy tuyến đường nào!');

    return routes.map<RouteResult>((r) {
      // duration có dạng "165s"
      final durStr = (r['duration'] as String? ?? '0s').replaceAll('s', '');
      return RouteResult(
        encodedPolyline: r['polyline']['encodedPolyline'] as String,
        distanceMeters: (r['distanceMeters'] as num?)?.toInt() ?? 0,
        durationSeconds: double.tryParse(durStr)?.round() ?? 0,
      );
    }).toList();
  }

  /// Geocoding API: "227 Nguyễn Văn Cừ, TP.HCM" -> tọa độ.
  static Future<GeocodeResult> geocode(String address) async {
    _ensureKey();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address,
      'key': kApiKey,
      'language': 'vi',
      'region': 'vn',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) throw ApiException(_errorFrom(res));

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status == 'OK') {
      final r = (data['results'] as List).first;
      final loc = r['geometry']['location'];
      return GeocodeResult(
        LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
        r['formatted_address'] as String? ?? address,
      );
    }
    if (status == 'ZERO_RESULTS') {
      throw ApiException('Không tìm thấy địa chỉ "$address"');
    }
    final msg = data['error_message'] as String? ?? status;
    throw ApiException('Geocoding lỗi: $msg');
  }

  /// Places API (New) - Nearby Search: tìm khách sạn, quán ăn, bệnh viện...
  /// [type] ví dụ: hotel, restaurant, hospital, school.
  static Future<List<PlaceItem>> searchNearby({
    required LatLng center,
    required String type,
    double radius = 2000,
  }) async {
    _ensureKey();
    final res = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Goog-Api-Key': kApiKey,
        'X-Goog-FieldMask':
            'places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode({
        'includedTypes': [type],
        'maxResultCount': 20,
        'languageCode': 'vi',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': center.latitude,
              'longitude': center.longitude,
            },
            'radius': radius,
          },
        },
      }),
    );
    if (res.statusCode != 200) throw ApiException(_errorFrom(res));

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final places = (data['places'] as List?) ?? [];
    return places.map<PlaceItem>((p) {
      final loc = p['location'];
      return PlaceItem(
        p['displayName']?['text'] as String? ?? 'Không tên',
        p['formattedAddress'] as String? ?? '',
        LatLng((loc['latitude'] as num).toDouble(),
            (loc['longitude'] as num).toDouble()),
      );
    }).toList();
  }
}

/// Giải mã chuỗi polyline (Encoded Polyline Algorithm) thành danh sách tọa độ.
List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0, lat = 0, lng = 0;
  final len = encoded.length;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return points;
}
