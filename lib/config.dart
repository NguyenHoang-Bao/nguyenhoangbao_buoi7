/// =====================================================================
///  CẤU HÌNH API KEY
///  Dán API key của bạn (lấy ở Google Cloud Console) vào dòng dưới.
///  Key này cũng phải được dán vào android/app/src/main/AndroidManifest.xml
///  (thẻ <meta-data android:name="com.google.android.geo.API_KEY" ...>).
///  KHÔNG đưa key thật lên Google Drive công khai / GitHub.
/// =====================================================================
const String kApiKey = 'AIzaSyBEtyDDRGpzJx6n_8C29SNqX1kMc2hOjF0';

/// true nếu đã thay key thật.
bool get hasApiKey => kApiKey.isNotEmpty && kApiKey != 'YOUR_API_KEY_HERE';

/// Vị trí mặc định của bản đồ: TP.HCM
const double kDefaultLat = 10.7769;
const double kDefaultLng = 106.7009;
