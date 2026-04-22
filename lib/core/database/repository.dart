import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities.dart';

const String tableAccounts = 'accounts';

class Repository {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'xflow.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $tableAccounts (id TEXT PRIMARY KEY, screen_name TEXT, auth_header TEXT)',
        );
      },
    );
  }

  static Future<void> insertAccount(Account account) async {
    final db = await database;
    await db.insert(
      tableAccounts,
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Account>> getAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableAccounts);
    return List.generate(maps.length, (i) {
      return Account.fromMap(maps[i]);
    });
  }
}
