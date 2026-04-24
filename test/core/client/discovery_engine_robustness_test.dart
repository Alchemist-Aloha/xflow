import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/discovery_engine.dart';
import 'package:xflow/core/models/tweet.dart';

void main() {
  Tweet createTweet(String id, String handle, {String? mediaUrl}) {
    return Tweet(
      id: id,
      userHandle: handle,
      text: 'Tweet $id',
      mediaUrls: [mediaUrl ?? 'url_$id'],
      createdAt: DateTime.now(),
    );
  }

  group('DiscoveryEngine Robustness Targets', () {
    test('Requirement: Saturation must handle both Handle and Media', () {
      final tweets = [
        createTweet('1', 'user_a', mediaUrl: 'vid_1'),
        createTweet('2', 'user_b', mediaUrl: 'vid_1'), // Duplicate Media
        createTweet('3', 'user_a', mediaUrl: 'vid_2'), // Duplicate Handle
        createTweet('4', 'user_c', mediaUrl: 'vid_3'),
        createTweet('5', 'user_d', mediaUrl: 'vid_4'),
      ];

      // With threshold 1, window 5:
      // Index 1 (vid_1) should be swapped away.
      // Index 2 (user_a) should be swapped away.
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);
      
      print('Handles: ${result.map((t) => t.userHandle).toList()}');
      print('Media: ${result.map((t) => t.mediaUrls.first).toList()}');

      // Check Window 0-2
      final window = result.sublist(0, 3);
      final handles = window.map((t) => t.userHandle).toSet();
      final media = window.map((t) => t.mediaUrls.first).toSet();
      
      expect(handles.length, equals(3), reason: 'Handle duplicate in window');
      expect(media.length, equals(3), reason: 'Media duplicate in window');
    });

    test('Requirement: Multi-pass saturation to prevent "leaks"', () {
      // Setup: Clump of 3 user_a, followed by 2 unique users.
      // [a, a, a, b, c]
      final tweets = [
        createTweet('1', 'user_a'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_a'),
        createTweet('4', 'user_b'),
        createTweet('5', 'user_c'),
      ];

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 10);
      print('Final handles: ${result.map((t) => t.userHandle).toList()}');

      // Index 1 and 2 should no longer be user_a
      expect(result[0].userHandle, 'user_a');
      expect(result[1].userHandle, isNot('user_a'));
      expect(result[2].userHandle, isNot('user_a'));
    });
  });
}
