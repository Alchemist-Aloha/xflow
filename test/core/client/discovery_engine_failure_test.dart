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

  group('DiscoveryEngine Failure Mode Tests', () {
    test('Failure: Total Pool Exhaustion (No valid swap candidates)', () {
      // Setup: 10 items, ALL from user_a.
      // threshold 1, window 10.
      final tweets = List.generate(10, (i) => createTweet('$i', 'user_a'));

      // Saturation will attempt to swap every single item but find nobody else.
      final result =
          DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 10);

      print('Handles: ${result.map((t) => t.userHandle).toList()}');
      // Should remain all user_a, but we should verify it didn't crash
      expect(result.length, 10);
      expect(result.every((t) => t.userHandle == 'user_a'), isTrue);
    });

    test('Failure: Tail Deadlock (Clump at the end)', () {
      // Setup: Diverse start, clump at the end.
      final tweets = [
        createTweet('1', 'user_a'),
        createTweet('2', 'user_b'),
        createTweet('3', 'user_c'),
        createTweet('4', 'user_a'),
        createTweet('5', 'user_a'), // Clump at end
      ];

      // threshold 1. Index 4 (user_a) is consecutive with index 3.
      // It looks for swaps after index 4. There are none.
      final result =
          DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);

      print('Tail handles: ${result.map((t) => t.userHandle).toList()}');
      // WEAKNESS: It cannot fix the tail.
      expect(result[4].userHandle, 'user_a');
      expect(result[3].userHandle, 'user_a');
    });
  });
}
