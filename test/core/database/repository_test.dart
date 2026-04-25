import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xflow/core/database/repository.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Repository Caching and Pruning Tests', () {
    setUp(() async {
      final db = await Repository.database;
      await db.delete(tableCachedMedia);
    });

    test('insertCachedMedia stores tweets correctly', () async {
      final now = DateTime.now();
      final tweets = [
        Tweet(
          id: 'repo_test_1',
          text: 'Test Tweet 1',
          userHandle: 'user1',
          mediaUrls: ['https://test.com/1.mp4'],
          isVideo: true,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        Tweet(
          id: 'repo_test_2',
          text: 'Test Tweet 2',
          userHandle: 'user2',
          mediaUrls: ['https://test.com/2.jpg'],
          isVideo: false,
          createdAt: now,
        ),
      ];

      await Repository.insertCachedMedia(tweets);
      
      // We check directly in DB because getUnplayedCachedMedia uses RANDOM()
      final db = await Repository.database;
      final results = await db.query(tableCachedMedia, where: "id LIKE 'repo_test_%'");

      expect(results.length, 2);
      expect(results.any((r) => r['id'] == 'repo_test_1'), true);
      expect(results.any((r) => r['id'] == 'repo_test_2'), true);
    });

    test('markMediaAsPlayed updates played_count and last_played_at', () async {
      final tweet = Tweet(
        id: 'play_test_unique',
        text: 'To be played',
        userHandle: 'tester',
        mediaUrls: [],
        createdAt: DateTime.now(),
      );

      await Repository.insertCachedMedia([tweet]);
      await Repository.markMediaAsPlayed('play_test_unique');

      final db = await Repository.database;
      final result = await db.query(tableCachedMedia, where: 'id = ?', whereArgs: ['play_test_unique']);
      expect(result.first['played_count'], 1);
      expect(result.first['last_played_at'], isNotNull);
    });

    test('pruneCachedMedia removes oldest WATCHED items when limit exceeded', () async {
      final db = await Repository.database;
      await db.delete(tableCachedMedia);
      
      for (int i = 1; i <= 5; i++) {
        await db.insert(tableCachedMedia, {
          'id': 'prune_test_$i',
          'played_count': 1,
          'last_played_at': i * 1000, 
          'text': 'Watched $i',
          'media_urls': '[]',
        });
      }

      await Repository.pruneCachedMedia(threshold: 3);

      final remaining = await db.query(tableCachedMedia, where: "id LIKE 'prune_test_%'");
      expect(remaining.length, 3);
      final remainingIds = remaining.map((row) => row['id']).toList();
      expect(remainingIds.contains('prune_test_1'), false);
      expect(remainingIds.contains('prune_test_2'), false);
      expect(remainingIds.contains('prune_test_3'), true);
    });
  });
}
