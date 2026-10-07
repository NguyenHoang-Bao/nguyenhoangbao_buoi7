import 'package:flutter_test/flutter_test.dart';
import 'package:nguyenhoangbao_buoi7/main.dart';

void main() {
  testWidgets('Trang chủ hiển thị danh sách bài tập', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Bài 07 - Google Maps'), findsOneWidget);
    expect(find.textContaining('Bài tập 1'), findsOneWidget);
    expect(find.textContaining('BTVN'), findsOneWidget);
  });
}
