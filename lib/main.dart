import 'package:flutter/material.dart';
import 'bthd1/maps_screen.dart';
import 'bthd2/router_finder_screen.dart';
import 'bthd4/route_finder_pro.dart';
import 'bthd5/route_planner_screen.dart';
import 'config.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bài 07 - Google Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const MainHomePage(),
    );
  }
}

class MainHomePage extends StatelessWidget {
  const MainHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Tên bài tập -> màn hình tương ứng
    final items = <String, Widget>{
      'Bài tập 1 - Map Navigator (vị trí hiện tại)': const MapScreen(),
      'Bài tập 2 - Route Finder (nhập 2 điểm)': const RouteFinderScreen(),
      'Bài tập 4 - Route Finder nâng cao (trên lớp)':
          const RouteFinderProScreen(),
      'BTVN - Route Planner (địa chỉ, phương tiện, yêu thích)':
          const RoutePlannerScreen(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Bài 07 - Google Maps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasApiKey)
            Card(
              color: Colors.red.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Chưa cấu hình API key!\n'
                  'Mở lib/config.dart và AndroidManifest.xml, dán API key Google Maps của bạn.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          for (final e in items.entries)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WithHomeButton(child: e.value),
                  ),
                ),
                child: Text(e.key, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bọc mỗi bài tập: thêm nút "Home" nổi để quay về trang chủ.
class WithHomeButton extends StatelessWidget {
  final Widget child;
  const WithHomeButton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 12,
          bottom: 96, // cao hơn thẻ thông tin ở cuối bản đồ
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Về trang chủ',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Icon(Icons.home),
          ),
        ),
      ],
    );
  }
}
