import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'favorite_route.dart';

/// Lớp truy cập SQLite cho bảng `favorites` (tuyến đường yêu thích).
/// Dùng mẫu Singleton: FavoritesDb.instance
class FavoritesDb {
  FavoritesDb._();
  static final FavoritesDb instance = FavoritesDb._();

  static const String _table = 'favorites';
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'favorites.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          start_address TEXT NOT NULL,
          end_address TEXT NOT NULL,
          start_lat REAL NOT NULL,
          start_lng REAL NOT NULL,
          end_lat REAL NOT NULL,
          end_lng REAL NOT NULL,
          mode TEXT NOT NULL,
          distance_m INTEGER NOT NULL,
          duration_s INTEGER NOT NULL,
          polyline TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      '''),
    );
  }

  /// Thêm tuyến yêu thích, trả về id mới.
  Future<int> insert(FavoriteRoute route) async {
    final db = await _database;
    return db.insert(_table, route.toMap());
  }

  /// Lấy toàn bộ danh sách, tuyến mới lưu nằm trên cùng.
  Future<List<FavoriteRoute>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'id DESC');
    return rows.map(FavoriteRoute.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
