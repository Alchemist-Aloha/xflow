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

  group('DiscoveryEngine Updated Tests', () {
    test('Verified: Media URL saturation works', () {
      final tweets = [
        createTweet('1', 'user_a', mediaUrl: 'vid_1'),
        createTweet('2', 'user_b', mediaUrl: 'vid_1'), // Duplicate Media
        createTweet('3', 'user_c', mediaUrl: 'vid_2'),
      ];

      final result = DiscoveryEngine.applySaturation(
        tweets, 
        threshold: 2, 
        mediaThreshold: 1, 
        windowSize: 5
      );
      
      print('Media URLs: ${result.map((t) => t.mediaUrls.first).toList()}');
      expect(result[0].mediaUrls.first, 'vid_1');
      expect(result[1].mediaUrls.first, 'vid_2');
      expect(result[2].mediaUrls.first, 'vid_1');
    });

    test('Verified: Multi-pass breaks clumps', () {
      // [a, a, a, b, c]
      final tweets = [
        createTweet('1', 'user_a'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_a'),
        createTweet('4', 'user_b'),
        createTweet('5', 'user_c'),
      ];

      // With threshold 1, window 10.
      // Pass 1: [a, b, a, a, c] -> swap 2 with 4
      // Pass 2: [a, b, c, a, a] -> swap 3 with 5
      final result = DiscoveryEngine.applySaturation(
        tweets, 
        threshold: 1, 
        windowSize: 10,
        maxPasses: 5
      );
      
      print('Handles: ${result.map((t) => t.userHandle).toList()}');
      expect(result[0].userHandle, 'user_a');
      expect(result[1].userHandle, 'user_b');
      expect(result[2].userHandle, 'user_c');
    });
  });
}
