import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'taskflow.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        repeats INTEGER NOT NULL DEFAULT 1,
        stopOnComplete INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      orderBy: 'hour ASC, minute ASC, title ASC',
    );

    return maps.map(Task.fromMap).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    if (task.id == null) {
      throw ArgumentError('Task.id is required to update.');
    }

    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
