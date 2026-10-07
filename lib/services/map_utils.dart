import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Hiện thông báo ngắn ở cuối màn hình.
void showMsg(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "10.776900, 106.700900"
String fmtLatLng(LatLng p) =>
    '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

/// Đọc chuỗi "lat, lng" thành LatLng. Ném [FormatException] nếu sai định dạng.
LatLng parseLatLng(String text) {
  final parts = text.split(',');
  if (parts.length != 2) {
    throw const FormatException('Tọa độ phải có dạng: vĩ độ, kinh độ');
  }
  final lat = double.parse(parts[0].trim());
  final lng = double.parse(parts[1].trim());
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw const FormatException('Tọa độ nằm ngoài phạm vi hợp lệ');
  }
  return LatLng(lat, lng);
}

/// Hình chữ nhật nhỏ nhất chứa tất cả các điểm.
LatLngBounds boundsFromPoints(List<LatLng> pts) {
  double minLat = pts.first.latitude, maxLat = pts.first.latitude;
  double minLng = pts.first.longitude, maxLng = pts.first.longitude;
  for (final p in pts) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// Di chuyển camera đến một vị trí.
Future<void> moveCamera(
  Completer<GoogleMapController> completer,
  LatLng position, {
  double? zoom,
}) async {
  final controller = await completer.future;
  controller.animateCamera(
    zoom == null
        ? CameraUpdate.newLatLng(position)
        : CameraUpdate.newLatLngZoom(position, zoom),
  );
}

/// Thu phóng bản đồ để thấy toàn bộ các điểm.
Future<void> fitPoints(
  Completer<GoogleMapController> completer,
  List<LatLng> pts,
) async {
  if (pts.length < 2) return;
  final controller = await completer.future;
  try {
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(boundsFromPoints(pts), 60),
    );
  } catch (_) {
    // Bản đồ chưa vẽ xong kích thước -> bỏ qua, không làm app lỗi.
  }
}
