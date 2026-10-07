import 'package:flutter/material.dart';
import '../services/google_api.dart';
import '../services/map_utils.dart';
import 'favorite_route.dart';
import 'favorites_db.dart';

IconData travelIcon(TravelType t) {
  switch (t) {
    case TravelType.drive:
      return Icons.directions_car;
    case TravelType.twoWheeler:
      return Icons.two_wheeler;
    case TravelType.walk:
      return Icons.directions_walk;
    case TravelType.bicycle:
      return Icons.directions_bike;
  }
}
/// Màn hình danh sách tuyến yêu thích.
/// Chạm vào một tuyến -> đóng màn hình và trả tuyến đó về màn hình bản đồ.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteRoute> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await FavoritesDb.instance.getAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(FavoriteRoute r) async {
    await FavoritesDb.instance.delete(r.id!);
    if (!mounted) return;
    showMsg(context, 'Đã xóa "${r.name}"');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tuyến đường yêu thích')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Chưa có tuyến yêu thích nào.'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = _items[index];
                    return ListTile(
                      leading: CircleAvatar(child: Icon(travelIcon(r.mode))),
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.startAddress} → ${r.endAddress}\n'
                        '${formatDistance(r.distanceMeters)} • '
                        '${formatDuration(r.durationSeconds)} • ${r.mode.label}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(r),
                      ),
                      onTap: () => Navigator.pop(context, r),
                    );
                  },
                ),
    );
  }
}
