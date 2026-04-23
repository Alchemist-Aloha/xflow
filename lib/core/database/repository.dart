import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities.dart';

const String tableAccounts = 'accounts';
const String tableSubscriptions = 'subscriptions';

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
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $tableAccounts (id TEXT PRIMARY KEY, screen_name TEXT, rest_id TEXT, auth_header TEXT)',
        );
        await db.execute(
          'CREATE TABLE $tableSubscriptions (id TEXT PRIMARY KEY, screen_name TEXT, name TEXT, profile_image_url TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $tableAccounts ADD COLUMN rest_id TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $tableSubscriptions (id TEXT PRIMARY KEY, screen_name TEXT, name TEXT, profile_image_url TEXT)',
          );
        }
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

  static Future<void> insertSubscription(Subscription sub) async {
    final db = await database;
    await db.insert(
      tableSubscriptions,
      sub.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> insertSubscriptions(List<Subscription> subs) async {
    final db = await database;
    final batch = db.batch();
    for (var sub in subs) {
      batch.insert(tableSubscriptions, sub.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Subscription>> getSubscriptions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableSubscriptions);
    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  static Future<void> clearSubscriptions() async {
    final db = await database;
    await db.delete(tableSubscriptions);
  }
}
