import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config.dart';
import '../services/google_api.dart';
import '../services/location_service.dart';
import '../services/map_utils.dart';

enum PickMode { none, start, end }

class RouteFinderProScreen extends StatefulWidget {
  const RouteFinderProScreen({super.key});

  @override
  State<RouteFinderProScreen> createState() => _RouteFinderProScreenState();
}

class _RouteFinderProScreenState extends State<RouteFinderProScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  LatLng? _start;
  LatLng? _end;
  LatLng? _myPosition;
  bool _locationGranted = false;
  PickMode _pickMode = PickMode.none;
  RouteResult? _route;
  Set<Marker> _placeMarkers = {};
  String? _activeType; // loại địa điểm đang tìm
  bool _loading = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(kDefaultLat, kDefaultLng),
    zoom: 13,
  );

  // Loại địa điểm: (nhãn, mã type của Places API, icon)
  static const List<(String, String, IconData)> _placeTypes = [
    ('Khách sạn', 'hotel', Icons.hotel),
    ('Quán ăn', 'restaurant', Icons.restaurant),
    ('Bệnh viện', 'hospital', Icons.local_hospital),
    ('Trường học', 'school', Icons.school),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // Vị trí hiện tại
  Future<void> _initLocation() async {
    try {
      final pos = await getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _locationGranted = true;
        _myPosition = here;
      });
      _setStart(here);
      moveCamera(_controller, here, zoom: 14);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  // Nút: lấy vị trí hiện tại làm điểm đích
  Future<void> _useMyLocationAsDestination() async {
    try {
      final pos = await getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _locationGranted = true;
        _myPosition = here;
      });
      _setEnd(here);
      moveCamera(_controller, here, zoom: 15);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  // Đặt điểm xuất phát / đích (cập nhật cả ô nhập và marker)
  void _setStart(LatLng p) {
    setState(() {
      _start = p;
      _startController.text = fmtLatLng(p);
      _route = null;
    });
  }

  void _setEnd(LatLng p) {
    setState(() {
      _end = p;
      _endController.text = fmtLatLng(p);
      _route = null;
    });
  }

  // Người dùng chạm lên bản đồ
  void _onMapTap(LatLng p) {
    switch (_pickMode) {
      case PickMode.start:
        _setStart(p);
        setState(() => _pickMode = PickMode.none);
        break;
      case PickMode.end:
        _setEnd(p);
        setState(() => _pickMode = PickMode.none);
        break;
      case PickMode.none:
        showMsg(context, 'Hãy bấm "Chọn xuất phát" hoặc "Chọn đích" trước khi chạm bản đồ');
    }
  }

  // Tìm đường
  Future<void> _findRoute() async {
    if (_startController.text.trim().isEmpty ||
        _endController.text.trim().isEmpty) {
      showMsg(context, 'Vui lòng nhập cả hai điểm!');
      return;
    }
    setState(() => _loading = true);
    try {
      final start = parseLatLng(_startController.text);
      final end = parseLatLng(_endController.text);
      final routes =
          await GoogleApi.computeRoutes(origin: start, destination: end);
      if (!mounted) return;
      setState(() {
        _start = start;
        _end = end;
        _route = routes.first;
      });
      fitPoints(_controller, routes.first.points);
    } on FormatException catch (e) {
      showMsg(context, 'Tọa độ không hợp lệ: ${e.message}');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Tìm địa điểm lân cận
  Future<void> _searchPlaces(String label, String type) async {
    // Bấm lại cùng loại -> tắt kết quả
    if (_activeType == type) {
      setState(() {
        _activeType = null;
        _placeMarkers = {};
      });
      return;
    }

    final center = _start ?? _myPosition ?? const LatLng(kDefaultLat, kDefaultLng);
    setState(() {
      _activeType = type;
      _loading = true;
    });
    try {
      final places = await GoogleApi.searchNearby(center: center, type: type);
      if (!mounted) return;
      if (places.isEmpty) {
        showMsg(context, 'Không tìm thấy "$label" trong bán kính 2 km');
      }
      final markers = <Marker>{};
      for (var i = 0; i < places.length; i++) {
        final place = places[i];
        markers.add(Marker(
          markerId: MarkerId('place_$i'),
          position: place.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
          // Chạm vào marker -> chọn làm điểm đích
          onTap: () {
            _setEnd(place.location);
            showMsg(context, 'Đã chọn "${place.name}" làm điểm đích');
          },
        ));
      }
      setState(() => _placeMarkers = markers);
      if (places.isNotEmpty) {
        fitPoints(_controller, [center, ...places.map((p) => p.location)]);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _activeType = null);
        showMsg(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Dữ liệu hiển thị trên bản đồ
  Set<Marker> get _allMarkers {
    final set = <Marker>{};
    if (_start != null) {
      set.add(Marker(
        markerId: const MarkerId('start'),
        position: _start!,
        infoWindow: const InfoWindow(title: 'Xuất phát'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (_end != null) {
      set.add(Marker(
        markerId: const MarkerId('end'),
        position: _end!,
        infoWindow: const InfoWindow(title: 'Đích đến'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    set.addAll(_placeMarkers);
    return set;
  }

  Set<Polyline> get _polylines {
    final r = _route;
    if (r == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: r.points,
        color: Colors.blue,
        width: 5,
      ),
    };
  }
  // Giao diện
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Finder (nâng cao)')),
      body: Column(
        children: [
          // --- Khu vực nhập liệu ---
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Column(
              children: [
                TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: 'Điểm xuất phát (lat, lng)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'Điểm đích (lat, lng)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _findRoute,
                      child: const Text('Tìm đường đi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _useMyLocationAsDestination,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Vị trí hiện tại → đích'),
                    ),
                    ChoiceChip(
                      label: const Text('Chọn xuất phát'),
                      selected: _pickMode == PickMode.start,
                      onSelected: (v) => setState(
                          () => _pickMode = v ? PickMode.start : PickMode.none),
                    ),
                    ChoiceChip(
                      label: const Text('Chọn đích'),
                      selected: _pickMode == PickMode.end,
                      onSelected: (v) => setState(
                          () => _pickMode = v ? PickMode.end : PickMode.none),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // --- Tìm địa điểm lân cận ---
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final t in _placeTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(t.$3, size: 18),
                      label: Text(t.$1),
                      selected: _activeType == t.$2,
                      onSelected: (_) => _searchPlaces(t.$1, t.$2),
                    ),
                  ),
              ],
            ),
          ),
          if (_pickMode != PickMode.none)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(6),
              child: Text(
                _pickMode == PickMode.start
                    ? 'Chạm vào bản đồ để chọn điểm XUẤT PHÁT'
                    : 'Chạm vào bản đồ để chọn điểm ĐÍCH',
                textAlign: TextAlign.center,
              ),
            ),
          // --- Bản đồ + thẻ thông tin khoảng cách / thời gian ---
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialPosition,
                  markers: _allMarkers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController c) {
                    if (!_controller.isCompleted) _controller.complete(c);
                  },
                  onTap: _onMapTap,
                  myLocationEnabled: _locationGranted,
                ),
                if (_loading)
                  const Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_route != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(children: [
                              const Icon(Icons.straighten),
                              const SizedBox(width: 6),
                              Text(_route!.distanceText,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ]),
                            Row(children: [
                              const Icon(Icons.access_time),
                              const SizedBox(width: 6),
                              Text(_route!.durationText,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
