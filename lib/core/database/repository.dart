import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities.dart';
import '../models/tweet.dart';
import '../../features/settings/settings_provider.dart';
import '../utils/app_logger.dart';

const String tableAccounts = 'accounts';
const String tableSubscriptions = 'subscriptions';
const String tableCachedMedia = 'cached_media';
const String tableHashtags = 'hashtags';

class Repository {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      path = inMemoryDatabasePath;
    } else {
      path = join(await getDatabasesPath(), 'xflow.db');
    }
    return await openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $tableAccounts (id TEXT PRIMARY KEY, screen_name TEXT, rest_id TEXT, auth_header TEXT)',
        );
        await db.execute(
          'CREATE TABLE $tableSubscriptions (id TEXT PRIMARY KEY, screen_name TEXT, name TEXT, profile_image_url TEXT, description TEXT, followers_count INTEGER, following_count INTEGER)',
        );
        await db.execute(
          'CREATE TABLE $tableHashtags (tag TEXT PRIMARY KEY, added_at INTEGER)',
        );
        await db.execute('''
          CREATE TABLE $tableCachedMedia (
            id TEXT PRIMARY KEY,
            text TEXT,
            user_handle TEXT,
            user_avatar_url TEXT,
            media_key TEXT,
            media_urls TEXT,
            thumbnail_url TEXT,
            is_video INTEGER,
            created_at INTEGER,
            played_count INTEGER DEFAULT 0,
            last_played_at INTEGER,
            duration_watched INTEGER DEFAULT 0,
            last_suggested_at INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_discovery_lookup ON $tableCachedMedia (played_count, created_at DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_media_key ON $tableCachedMedia (media_key)',
        );
        await db.execute(
          'CREATE INDEX idx_suggested ON $tableCachedMedia (last_suggested_at)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db
              .execute('ALTER TABLE $tableAccounts ADD COLUMN rest_id TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $tableSubscriptions (id TEXT PRIMARY KEY, screen_name TEXT, name TEXT, profile_image_url TEXT)',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE $tableSubscriptions ADD COLUMN description TEXT');
          await db.execute(
              'ALTER TABLE $tableSubscriptions ADD COLUMN followers_count INTEGER');
          await db.execute(
              'ALTER TABLE $tableSubscriptions ADD COLUMN following_count INTEGER');
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
        if (oldVersion < 6) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_discovery_lookup ON $tableCachedMedia (played_count, created_at DESC)',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
              'ALTER TABLE $tableCachedMedia ADD COLUMN media_key TEXT');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_media_key ON $tableCachedMedia (media_key)');
        }
        if (oldVersion < 8) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $tableHashtags (tag TEXT PRIMARY KEY, added_at INTEGER)',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
              'ALTER TABLE $tableCachedMedia ADD COLUMN last_suggested_at INTEGER');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_suggested ON $tableCachedMedia (last_suggested_at)');
        }
      },
    );
  }

  static Future<void> addHashtag(String tag) async {
    final db = await database;
    await db.insert(
      tableHashtags,
      {'tag': tag, 'added_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<String>> getHashtags() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(tableHashtags, orderBy: 'added_at DESC');
    return List.generate(maps.length, (i) => maps[i]['tag'] as String);
  }

  static Future<void> deleteHashtag(String tag) async {
    final db = await database;
    await db.delete(tableHashtags, where: 'tag = ?', whereArgs: [tag]);
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
      batch.insert(tableSubscriptions, sub.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
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
          'media_key': tweet.mediaKey,
          'media_urls': jsonEncode(tweet.mediaUrls),
          'thumbnail_url': tweet.thumbnailUrl,
          'is_video': tweet.isVideo ? 1 : 0,
          'created_at': tweet.createdAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm
            .ignore, // Don't overwrite play counts if already exists
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Tweet>> getUnplayedCachedMedia(int limit,
      {Set<MediaFilter>? filters}) async {
    final db = await database;

    // Use a subquery to exclude any tweets whose media_key has been played elsewhere
    String whereClause = 'played_count = 0';
    whereClause +=
        ' AND (media_key IS NULL OR media_key NOT IN (SELECT media_key FROM $tableCachedMedia WHERE played_count > 0 AND media_key IS NOT NULL))';

    List<dynamic> whereArgs = [];

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
      orderBy: 'last_suggested_at ASC',
      limit: limit * 2,
    );

    if (maps.isEmpty) return [];

    final results = List.generate(maps.length, (i) {
      return Tweet(
        id: maps[i]['id'] as String,
        text: maps[i]['text'] as String,
        userHandle: maps[i]['user_handle'] as String,
        userAvatarUrl: maps[i]['user_avatar_url'] as String?,
        mediaKey: maps[i]['media_key'] as String?,
        mediaUrls:
            List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int)
            : null,
      );
    });

    // Mark these as suggested
    if (results.isNotEmpty) {
      final ids = results.map((t) => t.id).toList();
      await markAsSuggested(ids);
    }

    return (results..shuffle()).take(limit).toList();
  }

  static Future<List<Tweet>> getCachedMediaCandidates(
    int limit, {
    required bool avoidWatchedContent,
    Set<MediaFilter>? filters,
  }) async {
    if (avoidWatchedContent) {
      return getUnplayedCachedMedia(limit, filters: filters);
    }

    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

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
        whereClause = '(${conditions.join(' OR ')})';
        whereArgs = [];
      }
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableCachedMedia,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'last_suggested_at ASC',
      limit: limit * 2, // Fetch more to allow for shuffling
    );

    final results = List.generate(maps.length, (i) {
      return Tweet(
        id: maps[i]['id'] as String,
        text: maps[i]['text'] as String,
        userHandle: maps[i]['user_handle'] as String,
        userAvatarUrl: maps[i]['user_avatar_url'] as String?,
        mediaKey: maps[i]['media_key'] as String?,
        mediaUrls:
            List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int)
            : null,
      );
    });

    // Mark these as suggested so they go to the back of the queue
    if (results.isNotEmpty) {
      final ids = results.map((t) => t.id).toList();
      await markAsSuggested(ids);
    }

    return (results..shuffle()).take(limit).toList();
  }

  static Future<void> markAsSuggested(List<String> ids) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        tableCachedMedia,
        {'last_suggested_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<Map<String, int>> getPlayedCountsByUser() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT LOWER(REPLACE(user_handle, '@', '')) AS normalized_handle,
             SUM(played_count) AS total_played
      FROM $tableCachedMedia
      GROUP BY normalized_handle
    ''');

    final out = <String, int>{};
    for (final row in rows) {
      final handle = row['normalized_handle'] as String?;
      if (handle == null || handle.isEmpty) continue;
      out[handle] = (row['total_played'] as int?) ?? 0;
    }
    return out;
  }

  static Future<List<Tweet>> getUserCachedMedia(String userHandle, int limit,
      {Set<MediaFilter>? filters}) async {
    final db = await database;
    // Strip @ if present for normalization
    final rawHandle =
        userHandle.startsWith('@') ? userHandle.substring(1) : userHandle;
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
        mediaKey: maps[i]['media_key'] as String?,
        mediaUrls:
            List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int)
            : null,
      );
    });
  }

  static Future<List<Tweet>> getHashtagCachedMedia(String hashtag, int limit,
      {Set<MediaFilter>? filters}) async {
    final db = await database;

    String whereClause = 'text LIKE ?';
    List<dynamic> whereArgs = ['%$hashtag%'];

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
        mediaKey: maps[i]['media_key'] as String?,
        mediaUrls:
            List<String>.from(jsonDecode(maps[i]['media_urls'] as String)),
        thumbnailUrl: maps[i]['thumbnail_url'] as String?,
        isVideo: (maps[i]['is_video'] as int) == 1,
        createdAt: maps[i]['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int)
            : null,
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

  static Future<int> getMediaPlayedCount(String id) async {
    final db = await database;
    final maps = await db.query(
      tableCachedMedia,
      columns: ['played_count'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return (maps.first['played_count'] as int?) ?? 0;
    }
    return 0;
  }

  static Future<int> getUserPlayedCount(String userHandle) async {
    final db = await database;
    final normalized = userHandle.replaceAll('@', '').toLowerCase();
    final rows = await db.rawQuery('''
      SELECT SUM(played_count) AS total_played
      FROM $tableCachedMedia
      WHERE LOWER(REPLACE(user_handle, '@', '')) = ?
    ''', [normalized]);

    if (rows.isNotEmpty) {
      return (rows.first['total_played'] as int?) ?? 0;
    }
    return 0;
  }

  static Future<int> getCachedMediaCount() async {
    final db = await database;
    final countSq =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableCachedMedia');
    return countSq.first['count'] as int;
  }

  static Future<void> pruneCachedMedia({int threshold = 5000}) async {
    final db = await database;

    // 1. Delete by age: Remove anything older than 7 days
    final sevenDaysAgo =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await db.delete(
      tableCachedMedia,
      where: 'created_at < ?',
      whereArgs: [sevenDaysAgo],
    );

    // 2. Delete by count: If still over threshold, delete oldest watched items
    final countSq =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableCachedMedia');
    final count = countSq.first['count'] as int;

    if (count > threshold) {
      final deleteCount = count - threshold;
      await db.execute('''
        DELETE FROM $tableCachedMedia 
        WHERE id IN (
          SELECT id FROM $tableCachedMedia 
          ORDER BY COALESCE(last_played_at, created_at) ASC 
          LIMIT ?
        )
      ''', [deleteCount]);
    }
  }

  static Future<void> purgeSeenMetadata() async {
    final db = await database;
    await db.delete(
      tableCachedMedia,
      where: 'played_count > 0',
    );
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
