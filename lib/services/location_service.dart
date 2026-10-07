import 'package:geolocator/geolocator.dart';
import 'google_api.dart';

/// Lấy vị trí hiện tại. Ném [ApiException] kèm thông báo tiếng Việt nếu
/// GPS tắt hoặc chưa được cấp quyền.
Future<Position> getCurrentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw ApiException('Vui lòng bật dịch vụ vị trí (GPS)!');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw ApiException('Ứng dụng chưa được cấp quyền truy cập vị trí!');
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}
