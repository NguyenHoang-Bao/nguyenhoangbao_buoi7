import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config.dart';
import '../services/google_api.dart';
import '../services/location_service.dart';
import '../services/map_utils.dart';

/// Bài tập 2: nhập hai điểm (xuất phát, đích) dạng "lat, lng",
/// đánh dấu marker tại hai điểm và vẽ đường đi (polyline).
class RouteFinderScreen extends StatefulWidget {
  const RouteFinderScreen({super.key});

  @override
  State<RouteFinderScreen> createState() => _RouteFinderScreenState();
}

class _RouteFinderScreenState extends State<RouteFinderScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  bool _locationGranted = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(kDefaultLat, kDefaultLng), // TP.HCM mặc định
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // Lấy vị trí hiện tại và điền vào ô "xuất phát"
  Future<void> _getCurrentLocation() async {
    try {
      final position = await getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() {
        _locationGranted = true;
        _addMarker(here, 'Xuất phát');
        _startController.text = fmtLatLng(here);
      });
      moveCamera(_controller, here, zoom: 14);
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

  // Tìm đường đi
  Future<void> _findRoute() async {
    if (_startController.text.trim().isEmpty ||
        _endController.text.trim().isEmpty) {
      showMsg(context, 'Vui lòng nhập cả hai điểm!');
      return;
    }

    try {
      final start = parseLatLng(_startController.text);
      final end = parseLatLng(_endController.text);
      final routes =
          await GoogleApi.computeRoutes(origin: start, destination: end);
      final route = routes.first;
      if (!mounted) return;
      setState(() {
        _markers.clear();
        _addMarker(start, 'Xuất phát');
        _addMarker(end, 'Đích đến');
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: route.points,
            color: Colors.blue,
            width: 5,
          ));
      });
      showMsg(context, 'Khoảng cách ${route.distanceText} • ${route.durationText}');
      fitPoints(_controller, route.points);
    } on FormatException catch (e) {
      showMsg(context, 'Tọa độ không hợp lệ: ${e.message}');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Finder')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: 'Điểm xuất phát (lat, lng)',
                  ),
                ),
                TextField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'Điểm đích (lat, lng)',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _findRoute,
                  child: const Text('Tìm đường đi'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) _controller.complete(controller);
              },
              myLocationEnabled: _locationGranted,
            ),
          ),
        ],
      ),
    );
  }
}
