import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities.dart';
import '../models/tweet.dart';
import '../../features/settings/settings_provider.dart';

const String tableAccounts = 'accounts';
const String tableSubscriptions = 'subscriptions';
const String tableCachedMedia = 'cached_media';

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
      version: 5,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $tableAccounts (id TEXT PRIMARY KEY, screen_name TEXT, rest_id TEXT, auth_header TEXT)',
        );
        await db.execute(
          'CREATE TABLE $tableSubscriptions (id TEXT PRIMARY KEY, screen_name TEXT, name TEXT, profile_image_url TEXT, description TEXT, followers_count INTEGER, following_count INTEGER)',
        );
        await db.execute('''
          CREATE TABLE $tableCachedMedia (
            id TEXT PRIMARY KEY,
            text TEXT,
            user_handle TEXT,
            user_avatar_url TEXT,
            media_urls TEXT,
            thumbnail_url TEXT,
            is_video INTEGER,
            created_at INTEGER,
            played_count INTEGER DEFAULT 0,
            last_played_at INTEGER,
            duration_watched INTEGER DEFAULT 0
          )
        ''');
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
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE $tableSubscriptions ADD COLUMN description TEXT');
          await db.execute('ALTER TABLE $tableSubscriptions ADD COLUMN followers_count INTEGER');
          await db.execute('ALTER TABLE $tableSubscriptions ADD COLUMN following_count INTEGER');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableCachedMedia (
              id TEXT PRIMARY KEY,
              text TEXT,
              user_handle TEXT,
              user_avatar_url TEXT,
              media_urls TEXT,
              thumbnail_url TEXT,
              is_video INTEGER,
              created_at INTEGER,
              played_count INTEGER DEFAULT 0,
              last_played_at INTEGER,
              duration_watched INTEGER DEFAULT 0
            )
          ''');
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

  static Future<void> insertCachedMedia(List<Tweet> tweets) async {
    final db = await database;
    final batch = db.batch();
    for (var tweet in tweets) {
      batch.insert(
        tableCachedMedia,
        {
          'id': tweet.id,
          'text': tweet.text,
          'user_handle': tweet.userHandle,
          'user_avatar_url': tweet.userAvatarUrl,
          'media_urls': jsonEncode(tweet.mediaUrls),
          'thumbnail_url': tweet.thumbnailUrl,
          'is_video': tweet.isVideo ? 1 : 0,
          'created_at': tweet.createdAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Don't overwrite play counts if already exists
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Tweet>> getUnplayedCachedMedia(int limit, {Set<MediaFilter>? filters}) async {
    final db = await database;
    
    String whereClause = 'played_count = ?';
    List<dynamic> whereArgs = [0];

    if (filters != null && filters.isNotEmpty) {
      final conditions = <String>[];
      for (final filter in filters) {
        switch (filter) {
          case MediaFilter.video:
            conditions.add('is_video = 1');
            break;
          case MediaFilter.image:
            conditions.add('(media_urls != "[]" AND is_video = 0)');
            break;
          case MediaFilter.text:
            conditions.add('media_urls = "[]"');
            break;
        }
      }
      if (conditions.isNotEmpty) {
        whereClause += ' AND (${conditions.join(' OR ')})';
      }
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableCachedMedia,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return Tweet(
        id: maps[i]['id'] as String,
        text: maps[i]['text'] as String,
        userHandle: maps[i]['user_handle'] as String,
        userAvatarUrl: maps[i]['user_avatar_url'] as String?,
        mediaUrls: List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int) : null,
      );
    });
  }

  static Future<List<Tweet>> getUserCachedMedia(String userHandle, int limit, {Set<MediaFilter>? filters}) async {
    final db = await database;
    // Strip @ if present for normalization
    final rawHandle = userHandle.startsWith('@') ? userHandle.substring(1) : userHandle;
    final handleWithAt = '@$rawHandle';
    
    String whereClause = '(user_handle = ? OR user_handle = ?)';
    List<dynamic> whereArgs = [rawHandle, handleWithAt];

    if (filters != null && filters.isNotEmpty) {
      final conditions = <String>[];
      for (final filter in filters) {
        switch (filter) {
          case MediaFilter.video:
            conditions.add('is_video = 1');
            break;
          case MediaFilter.image:
            conditions.add('(media_urls != "[]" AND is_video = 0)');
            break;
          case MediaFilter.text:
            conditions.add('media_urls = "[]"');
            break;
        }
      }
      if (conditions.isNotEmpty) {
        whereClause += ' AND (${conditions.join(' OR ')})';
      }
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableCachedMedia,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return Tweet(
        id: maps[i]['id'] as String,
        text: maps[i]['text'] as String,
        userHandle: maps[i]['user_handle'] as String,
        userAvatarUrl: maps[i]['user_avatar_url'] as String?,
        mediaUrls: List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int) : null,
      );
    });
  }

  static Future<void> markMediaAsPlayed(String id) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE $tableCachedMedia 
      SET played_count = played_count + 1, last_played_at = ? 
      WHERE id = ?
    ''', [DateTime.now().millisecondsSinceEpoch, id]);
  }

  static Future<int> getCachedMediaCount() async {
    final db = await database;
    final countSq = await db.rawQuery('SELECT COUNT(*) as count FROM $tableCachedMedia');
    return countSq.first['count'] as int;
  }

  static Future<void> pruneCachedMedia({int threshold = 50000}) async {
    final db = await database;
    final countSq = await db.rawQuery('SELECT COUNT(*) as count FROM $tableCachedMedia');
    final count = countSq.first['count'] as int;

    if (count > threshold) {
      // Delete the oldest watched items
      final deleteCount = count - threshold;
      await db.execute('''
        DELETE FROM $tableCachedMedia 
        WHERE id IN (
          SELECT id FROM $tableCachedMedia 
          WHERE played_count > 0 
          ORDER BY last_played_at ASC 
          LIMIT ?
        )
      ''', [deleteCount]);
    }
  }
}
