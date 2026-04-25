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

  group('DiscoveryEngine Edge Case Tests', () {
    test('Edge Case: Case-sensitivity in handles', () {
      // Setup: Threshold 1, but handles vary by case
      final tweets = [
        createTweet('1', 'UserA'),
        createTweet('2', 'usera'),
        createTweet('3', 'UserB'),
      ];

      final result =
          DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);

      print('Handles: ${result.map((t) => t.userHandle).toList()}');
      bool hasDuplicateInWindow = result[0].userHandle.toLowerCase() ==
          result[1].userHandle.toLowerCase();

      expect(hasDuplicateInWindow, isFalse,
          reason: 'Saturation ignored case-sensitivity');
    });

    test('Edge Case: Duplicate Media URL (Different ID)', () {
      // Setup: Different IDs, but same Media URL
      final tweets = [
        createTweet('100', 'user_a', mediaUrl: 'same_vid'),
        createTweet('101', 'user_b', mediaUrl: 'other_vid'),
        createTweet('102', 'user_c',
            mediaUrl: 'third_vid'), // Added to provide swap candidate
        createTweet('103', 'user_d', mediaUrl: 'same_vid'),
      ];

      final result = DiscoveryEngine.applySaturation(tweets,
          threshold: 1, mediaThreshold: 1, windowSize: 5);

      print('Media URLs: ${result.map((t) => t.mediaUrls.first).toList()}');

      bool hasDuplicateMedia = false;
      for (int i = 0; i < result.length - 1; i++) {
        if (result[i].mediaUrls.first == result[i + 1].mediaUrls.first)
          hasDuplicateMedia = true;
      }
      expect(hasDuplicateMedia, isFalse,
          reason: 'Duplicate media found consecutively');
    });

    test('Edge Case: Clump larger than lookahead', () {
      // Setup: threshold 1, window 10.
      final tweets = [
        ...List.generate(20, (i) => createTweet('$i', 'user_a')),
        createTweet('99', 'user_b'),
        ...List.generate(20, (i) => createTweet('${i + 30}', 'user_c')),
        ...List.generate(20, (i) => createTweet('${i + 60}', 'user_d')),
      ];

      final result =
          DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);

      print(
          'Indices 0-5 handles: ${result.sublist(0, 5).map((t) => t.userHandle).toList()}');

      // Verify if it managed to pull non-'a' items up
      int userACount = 0;
      for (int i = 0; i < 5; i++) {
        if (result[i].userHandle == 'user_a') userACount++;
      }

      expect(userACount, lessThanOrEqualTo(2),
          reason: 'Failed to break large clump effectively');
    });
    group('DiscoveryEngine Extended Edge Cases', () {
      test('Extreme: All same user except one at the very end', () {
        final tweets = [
          ...List.generate(10, (i) => createTweet('$i', 'user_a')),
          createTweet('99', 'user_b'),
        ];

        final result = DiscoveryEngine.applySaturation(tweets,
            threshold: 1, windowSize: 10);
        // Should have moved user_b as far up as possible without violating other rules
        expect(result[1].userHandle, 'user_b');
      });
    });
  });
}
