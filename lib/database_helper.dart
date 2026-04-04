import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wahaty.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE parents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE children (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER NOT NULL,
        child_name TEXT NOT NULL,
        age TEXT NOT NULL,
        gender TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES parents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE forbidden_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES parents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        details TEXT NOT NULL,
        time TEXT NOT NULL,
        day_label TEXT NOT NULL,
        icon_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES parents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE usage_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER NOT NULL UNIQUE,
        selected_index INTEGER NOT NULL,
        auto_stop INTEGER NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES parents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE parent_passwords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER NOT NULL UNIQUE,
        password TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES parents (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS forbidden_words (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parent_id INTEGER NOT NULL,
          word TEXT NOT NULL,
          FOREIGN KEY (parent_id) REFERENCES parents (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parent_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          details TEXT NOT NULL,
          time TEXT NOT NULL,
          day_label TEXT NOT NULL,
          icon_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (parent_id) REFERENCES parents (id)
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usage_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parent_id INTEGER NOT NULL UNIQUE,
          selected_index INTEGER NOT NULL,
          auto_stop INTEGER NOT NULL,
          FOREIGN KEY (parent_id) REFERENCES parents (id)
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS parent_passwords (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parent_id INTEGER NOT NULL UNIQUE,
          password TEXT NOT NULL,
          FOREIGN KEY (parent_id) REFERENCES parents (id)
        )
      ''');
    }
  }

  Future<int> createParent({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await instance.database;

    return await db.insert('parents', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>?> loginParent({
    required String email,
    required String password,
  }) async {
    final db = await instance.database;

    final result = await db.query(
      'parents',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> createChild({
    required int parentId,
    required String childName,
    required String age,
    required String gender,
  }) async {
    final db = await instance.database;

    return await db.insert('children', {
      'parent_id': parentId,
      'child_name': childName,
      'age': age,
      'gender': gender,
    });
  }

  Future<Map<String, dynamic>?> getChild(int parentId) async {
    final db = await instance.database;

    final result = await db.query(
      'children',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getChildByParentId(int parentId) async {
    final db = await instance.database;

    final result = await db.query(
      'children',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> addForbiddenWord({
    required int parentId,
    required String word,
  }) async {
    final db = await instance.database;

    return await db.insert('forbidden_words', {
      'parent_id': parentId,
      'word': word,
    });
  }

  Future<List<Map<String, dynamic>>> getForbiddenWords(int parentId) async {
    final db = await instance.database;

    return await db.query(
      'forbidden_words',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'id DESC',
    );
  }

  Future<void> deleteForbiddenWord(int id) async {
    final db = await instance.database;

    await db.delete(
      'forbidden_words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addActivityLog({
    required int parentId,
    required String title,
    required String details,
    required String time,
    required String dayLabel,
    required String iconType,
    required String createdAt,
  }) async {
    final db = await instance.database;

    await db.insert('activity_logs', {
      'parent_id': parentId,
      'title': title,
      'details': details,
      'time': time,
      'day_label': dayLabel,
      'icon_type': iconType,
      'created_at': createdAt,
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs(int parentId) async {
    final db = await instance.database;

    return await db.query(
      'activity_logs',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'id DESC',
    );
  }

  Future<void> saveUsageSettings({
    required int parentId,
    required int selectedIndex,
    required bool autoStop,
  }) async {
    final db = await instance.database;

    await db.insert(
      'usage_settings',
      {
        'parent_id': parentId,
        'selected_index': selectedIndex,
        'auto_stop': autoStop ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUsageSettings(int parentId) async {
    final db = await instance.database;

    final result = await db.query(
      'usage_settings',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<void> saveParentPassword({
    required int parentId,
    required String password,
  }) async {
    final db = await instance.database;

    await db.insert(
      'parent_passwords',
      {
        'parent_id': parentId,
        'password': password,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getParentPassword(int parentId) async {
    final db = await instance.database;

    final result = await db.query(
      'parent_passwords',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['password'] as String;
    }
    return null;
  }
}