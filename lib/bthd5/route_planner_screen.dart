import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config.dart';
import '../services/google_api.dart';
import '../services/location_service.dart';
import '../services/map_utils.dart';
import 'favorite_route.dart';
import 'favorites_db.dart';
import 'favorites_screen.dart';

const String kMyLocation = 'Vị trí của tôi';

/// Bài tập về nhà:
///  - Nhập ĐỊA CHỈ (Geocoding API) thay vì tọa độ.
///  - Chọn phương tiện: ô tô, xe máy, đi bộ, xe đạp.
///  - Vẽ đường đi; tìm tuyến TỐI ƯU (nhanh nhất) trong các tuyến có thể.
///  - Lưu tuyến vào danh sách yêu thích (SQLite) và xem lại khi cần.
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _startCtl = TextEditingController();
  final TextEditingController _endCtl = TextEditingController();

  LatLng? _start; // null = cần geocode lại từ ô nhập
  LatLng? _end;
  String _startAddress = '';
  String _endAddress = '';
  TravelType _mode = TravelType.drive;

  /// Các tuyến tìm được, đã sắp xếp theo thời gian: phần tử 0 là tối ưu nhất.
  List<RouteResult> _routes = [];
  bool _loading = false;
  bool _locationGranted = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(kDefaultLat, kDefaultLng),
    zoom: 12,
  );

  @override
  void dispose() {
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }
  // Tìm đường
  Future<void> _search() async {
    final startText = _startCtl.text.trim();
    final endText = _endCtl.text.trim();
    if (endText.isEmpty) {
      showMsg(context, 'Vui lòng nhập điểm đến!');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      // --- Điểm xuất phát ---
      if (_start == null) {
        if (startText.isEmpty || startText == kMyLocation) {
          final pos = await getCurrentPosition();
          _start = LatLng(pos.latitude, pos.longitude);
          _startAddress = kMyLocation;
          _startCtl.text = kMyLocation;
          _locationGranted = true;
        } else {
          final g = await GoogleApi.geocode(startText);
          _start = g.location;
          _startAddress = g.formattedAddress;
        }
      }
      // --- Điểm đến (Geocoding: địa chỉ -> tọa độ) ---
      if (_end == null) {
        final g = await GoogleApi.geocode(endText);
        _end = g.location;
        _endAddress = g.formattedAddress;
      }

      // --- Routes API: lấy cả tuyến thay thế để chọn tuyến tối ưu ---
      final routes = await GoogleApi.computeRoutes(
        origin: _start!,
        destination: _end!,
        mode: _mode,
        alternatives: true,
      );
      routes.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));

      if (!mounted) return;
      setState(() => _routes = routes);
      fitPoints(_controller, routes.first.points);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useMyLocation() {
    setState(() {
      _start = null;
      _startCtl.text = kMyLocation;
    });
  }

  // Yêu thích (SQLite)
  Future<void> _saveFavorite() async {
    if (_routes.isEmpty || _start == null || _end == null) return;
    final best = _routes.first;

    final nameCtl = TextEditingController(
      text: '${_shortName(_startAddress)} → ${_shortName(_endAddress)}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lưu tuyến yêu thích'),
        content: TextField(
          controller: nameCtl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên tuyến'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await FavoritesDb.instance.insert(FavoriteRoute(
      name: name,
      startAddress: _startAddress,
      endAddress: _endAddress,
      start: _start!,
      end: _end!,
      mode: _mode,
      distanceMeters: best.distanceMeters,
      durationSeconds: best.durationSeconds,
      polyline: best.encodedPolyline,
    ));
    if (mounted) showMsg(context, 'Đã lưu "$name" vào yêu thích');
  }

  String _shortName(String address) {
    final first = address.split(',').first.trim();
    return first.isEmpty ? address : first;
  }

  Future<void> _openFavorites() async {
    final fav = await Navigator.push<FavoriteRoute>(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
    if (fav == null || !mounted) return;

    // Hiển thị lại tuyến đã lưu (không cần gọi lại API)
    setState(() {
      _start = fav.start;
      _end = fav.end;
      _startAddress = fav.startAddress;
      _endAddress = fav.endAddress;
      _startCtl.text = fav.startAddress;
      _endCtl.text = fav.endAddress;
      _mode = fav.mode;
      _routes = [fav.toRouteResult()];
    });
    fitPoints(_controller, _routes.first.points);
  }

  // ---------------------------------------------------------------------
  // Dữ liệu vẽ lên bản đồ
  // ---------------------------------------------------------------------
  Set<Marker> get _markers {
    final set = <Marker>{};
    if (_routes.isEmpty) return set;
    if (_start != null) {
      set.add(Marker(
        markerId: const MarkerId('start'),
        position: _start!,
        infoWindow: InfoWindow(title: 'Xuất phát', snippet: _startAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (_end != null) {
      set.add(Marker(
        markerId: const MarkerId('end'),
        position: _end!,
        infoWindow: InfoWindow(title: 'Đích đến', snippet: _endAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    return set;
  }

  Set<Polyline> get _polylines {
    final set = <Polyline>{};
    for (var i = 0; i < _routes.length; i++) {
      final isBest = i == 0;
      set.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: _routes[i].points,
        color: isBest ? Colors.blue : Colors.grey,
        width: isBest ? 7 : 4,
        zIndex: isBest ? 1 : 0, // tuyến tối ưu vẽ đè lên trên
      ));
    }
    return set;
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planner'),
        actions: [
          IconButton(
            tooltip: 'Tuyến yêu thích',
            icon: const Icon(Icons.favorite),
            onPressed: _openFavorites,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Column(
              children: [
                TextField(
                  controller: _startCtl,
                  onChanged: (_) => _start = null, // sửa chữ -> geocode lại
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Điểm xuất phát (địa chỉ)',
                    hintText: 'Để trống = vị trí của tôi',
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: 'Dùng vị trí của tôi',
                      icon: const Icon(Icons.my_location),
                      onPressed: _useMyLocation,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _endCtl,
                  onChanged: (_) => _end = null,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Điểm đến (địa chỉ)',
                    hintText: '227 Nguyễn Văn Cừ, TP.HCM',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          // Chọn phương tiện
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final t in TravelType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(travelIcon(t), size: 18),
                      label: Text(t.label),
                      selected: _mode == t,
                      onSelected: (_) {
                        setState(() => _mode = t);
                        // Đã có tuyến -> tính lại theo phương tiện mới
                        if (_routes.isNotEmpty) _search();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Tìm đường'),
                  ),
                ),
              ],
            ),
          ),
          // Bản đồ + thẻ kết quả
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialPosition,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController c) {
                    if (!_controller.isCompleted) _controller.complete(c);
                  },
                  myLocationEnabled: _locationGranted,
                ),
                if (_loading)
                  const Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_routes.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(travelIcon(_mode), color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_routes.first.distanceText} • ${_routes.first.durationText}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    _routes.length > 1
                                        ? 'Tuyến tối ưu (nhanh nhất) trong ${_routes.length} tuyến'
                                        : 'Tuyến tối ưu • ${_mode.label}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Lưu vào yêu thích',
                              icon: const Icon(Icons.favorite_border),
                              onPressed: _saveFavorite,
                            ),
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
