import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('stratalms_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE courses (
  id $idType,
  list_type $textType,
  data $textType,
  updated_at $intType
)
''');

    await db.execute('''
CREATE TABLE course_trees (
  course_id $idType,
  data $textType,
  updated_at $intType
)
''');

    await db.execute('''
CREATE TABLE activities (
  activity_id $idType,
  course_id $textType,
  data $textType,
  updated_at $intType
)
''');

    await db.execute('''
CREATE TABLE progress_sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_id $textType,
  activity_id $textType,
  action $textType,
  payload $textType,
  created_at $intType
)
''');
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('courses');
    await db.delete('course_trees');
    await db.delete('activities');
    await db.delete('progress_sync_queue');
  }
}
