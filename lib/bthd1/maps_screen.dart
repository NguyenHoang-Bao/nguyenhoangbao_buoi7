import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/google_api.dart';
import '../services/location_service.dart';
import '../services/map_utils.dart';

/// Bài tập 1: hiển thị Google Maps, đánh dấu vị trí hiện tại,
/// (thêm) nút chỉ đường từ vị trí hiện tại đến một điểm đích.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  bool _locationGranted = false; // chỉ bật chấm xanh "vị trí của tôi" khi đã có quyền

  // Điểm đích ví dụ: TP.HCM
  final LatLng _destination = const LatLng(10.7769, 106.7009);

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(10.7769, 106.7009), // Vị trí mặc định: TP.HCM
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Lấy vị trí hiện tại của người dùng
  Future<void> _getCurrentLocation() async {
    try {
      final position = await getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() {
        _locationGranted = true;
        _currentPosition = here;
        _addMarker(here, 'Vị trí của bạn');
      });
      moveCamera(_controller, here, zoom: 15);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  // Thêm marker (gọi bên trong setState)
  void _addMarker(LatLng position, String markerId) {
    _markers.removeWhere((m) => m.markerId.value == markerId);
    _markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: markerId),
      ),
    );
  }

  // Tìm đường đi từ vị trí hiện tại đến điểm đích
  Future<void> _getDirections() async {
    final from = _currentPosition;
    if (from == null) {
      showMsg(context, 'Chưa xác định được vị trí hiện tại!');
      return;
    }
    try {
      final routes =
          await GoogleApi.computeRoutes(origin: from, destination: _destination);
      final route = routes.first;
      if (!mounted) return;
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: route.points,
            color: Colors.blue,
            width: 5,
          ));
        _addMarker(_destination, 'Đích đến');
      });
      showMsg(context, 'Khoảng cách ${route.distanceText} • ${route.durationText}');
      fitPoints(_controller, route.points);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Navigator')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
            },
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: _locationGranted,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bt1_directions',
        onPressed: _getDirections,
        icon: const Icon(Icons.directions),
        label: const Text('Chỉ đường'),
      ),
    );
  }
}
