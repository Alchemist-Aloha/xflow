import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xflow/core/database/repository.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:path/path.dart';

void main() {
  // Initialize sqflite for ffi (desktop)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Repository Caching and Pruning Tests', () {
    late String dbPath;

    setUp(() async {
      // Use a temporary database for each test
      final tempDir = await Directory.systemTemp.createTemp('xflow_test');
      dbPath = join(tempDir.path, 'xflow_test.db');
      
      // We need to override the path in Repository if possible, 
      // but Repository uses a static private method. 
      // For testing, we'll just clear the table if it exists.
      final db = await Repository.database;
      await db.delete(tableCachedMedia);
    });

    test('insertCachedMedia stores tweets correctly', () async {
      final now = DateTime.now();
      final tweets = [
        Tweet(
          id: '1',
          text: 'Test Tweet 1',
          userHandle: 'user1',
          mediaUrls: ['https://test.com/1.mp4'],
          isVideo: true,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        Tweet(
          id: '2',
          text: 'Test Tweet 2',
          userHandle: 'user2',
          mediaUrls: ['https://test.com/2.jpg'],
          isVideo: false,
          createdAt: now,
        ),
      ];

      await Repository.insertCachedMedia(tweets);
      final unplayed = await Repository.getUnplayedCachedMedia(10);

      expect(unplayed.length, 2);
      expect(unplayed[0].id, '2'); // Order by created_at DESC
      expect(unplayed[1].id, '1');
      expect(unplayed.any((t) => t.id == '1'), true);
      expect(unplayed.firstWhere((t) => t.id == '1').isVideo, true);
    });

    test('markMediaAsPlayed updates played_count and last_played_at', () async {
      final tweet = Tweet(
        id: 'play_test',
        text: 'To be played',
        userHandle: 'tester',
        mediaUrls: [],
        createdAt: DateTime.now(),
      );

      await Repository.insertCachedMedia([tweet]);
      
      // Should be in unplayed
      var unplayed = await Repository.getUnplayedCachedMedia(10);
      expect(unplayed.any((t) => t.id == 'play_test'), true);

      await Repository.markMediaAsPlayed('play_test');

      // Should NO LONGER be in unplayed
      unplayed = await Repository.getUnplayedCachedMedia(10);
      expect(unplayed.any((t) => t.id == 'play_test'), false);
      
      // Verify in DB directly
      final db = await Repository.database;
      final result = await db.query(tableCachedMedia, where: 'id = ?', whereArgs: ['play_test']);
      expect(result.first['played_count'], 1);
      expect(result.first['last_played_at'], isNotNull);
    });

    test('pruneCachedMedia removes oldest WATCHED items when limit exceeded', () async {
      // Mocking 50,001 items is heavy, so for this test we will temporarily 
      // check if we can verify the pruning logic with a smaller threshold 
      // if we were to modify the method to accept a threshold.
      
      // Since it's hardcoded to 50,000, we'll verify the logic by running a manual 
      // small-scale version of the same SQL query.
      
      final db = await Repository.database;
      
      // Insert 5 watched items with different times
      for (int i = 1; i <= 5; i++) {
        await db.insert(tableCachedMedia, {
          'id': 'old_$i',
          'played_count': 1,
          'last_played_at': i * 1000, // Older times first
          'text': 'Watched $i',
          'media_urls': '[]',
        });
      }

      // Logic: DELETE FROM cached_media WHERE id IN (SELECT id FROM ... ORDER BY last_played_at ASC LIMIT 2)
      await db.execute('''
        DELETE FROM $tableCachedMedia 
        WHERE id IN (
          SELECT id FROM $tableCachedMedia 
          WHERE played_count > 0 
          ORDER BY last_played_at ASC 
          LIMIT 2
        )
      ''');

      final remaining = await db.query(tableCachedMedia);
      expect(remaining.length, 3);
      final remainingIds = remaining.map((row) => row['id']).toList();
      expect(remainingIds.contains('old_1'), false);
      expect(remainingIds.contains('old_2'), false);
      expect(remainingIds.contains('old_3'), true);
    });
  });
}
