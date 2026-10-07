# nguyenhoangbao_buoi7 – Bài 07: Google Maps (Flutter)

Sinh viên: Nguyễn Hoàng Bảo – MSSV 2001240034

## Nội dung các bài

| Bài | File | Chức năng |
|---|---|---|
| Bài tập 1 | `lib/bthd1/maps_screen.dart` | Hiển thị Google Maps, đánh dấu vị trí hiện tại, nút chỉ đường đến một điểm đích |
| Bài tập 2 | `lib/bthd2/router_finder_screen.dart` | Nhập 2 điểm (lat, lng), đánh dấu 2 marker, vẽ polyline đường đi |
| Bài tập 4 (trên lớp) | `lib/bthd4/route_finder_pro.dart` | Nút vị trí hiện tại → đích, khoảng cách + thời gian, chạm bản đồ để chọn điểm, tìm khách sạn / quán ăn / bệnh viện / trường học |
| BTVN | `lib/bthd5/route_planner_screen.dart` (+ `favorites_*.dart`, `favorite_route.dart`) | Nhập địa chỉ (Geocoding), chọn phương tiện, tuyến tối ưu, lưu tuyến yêu thích bằng SQLite |

Dùng chung: `lib/services/google_api.dart` (gọi API), `location_service.dart` (GPS), `map_utils.dart` (tiện ích bản đồ), `lib/config.dart` (API key).

## Cách chạy (làm lần lượt)

### 1. Tạo phần khung Android còn thiếu
Mở Terminal trong thư mục project này và chạy:

```
flutter create .
flutter pub get
```

`flutter create .` chỉ bổ sung các thư mục `android/`, `ios/`, `web/`... còn thiếu, **không ghi đè** `lib/`, `pubspec.yaml` và `AndroidManifest.xml` đã có.

### 2. Lấy API key (xem hướng dẫn trong file PDF Bài 07, mục 1.2)
Trong Google Cloud Console, bật các API sau cho project của bạn:

- **Maps SDK for Android**
- **Routes API** (thay cho Directions API – xem ghi chú bên dưới)
- **Places API (New)**
- **Geocoding API**

### 3. Dán API key vào 2 chỗ
1. `lib/config.dart` → `kApiKey`
2. `android/app/src/main/AndroidManifest.xml` → `android:value` của `com.google.android.geo.API_KEY`

(Nên giới hạn key theo Package name + SHA-1 như hướng dẫn trong PDF. Không chia sẻ key thật lên Drive/GitHub.)

### 4. Chạy
- Dùng máy ảo có **Google Play / Google APIs** (Pixel … API …).
- Bật GPS cho máy ảo: ba chấm `⋮` → **Location** → đặt vị trí (ví dụ TP.HCM `10.7769, 106.7009`) → **Set Location**.
- `flutter run` hoặc nút Run trong Android Studio.

## Ghi chú: vì sao dùng Routes API và Places API (New)?
PDF hướng dẫn dùng **Directions API**, nhưng từ 01/03/2025 Google chuyển Directions API và Places API cũ sang trạng thái *Legacy*: **project Google Cloud mới không bật được** hai API này. Vì vậy code dùng bản thay thế chính thức:

- Directions API → **Routes API** (`routes.googleapis.com/directions/v2:computeRoutes`)
- Places API → **Places API (New)** (`places.googleapis.com/v1/places:searchNearby`)
- Geocoding API vẫn dùng bình thường.

Cách hoạt động giữ nguyên như trong PDF: gọi API bằng `http`, nhận chuỗi *encoded polyline*, giải mã thành danh sách `LatLng` và vẽ bằng `Polyline`.

## Lỗi thường gặp
- **Bản đồ trắng / chỉ có lưới xám**: sai API key trong `AndroidManifest.xml`, hoặc chưa bật Maps SDK for Android.
- **"Lỗi 403 ... has not been used / is disabled"**: chưa bật Routes API / Places API (New) / Geocoding API.
- **"Lỗi 403 ... API key not valid"** hoặc bị chặn: key đang giới hạn sai Package name / SHA-1.
- **Không có vị trí**: chưa bật GPS của máy ảo (bước 4).
- Xem nhật ký lỗi chi tiết ở tab **Run** của Android Studio.
