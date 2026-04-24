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

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);
      
      print('Handles: ${result.map((t) => t.userHandle).toList()}');
      bool hasDuplicateInWindow = result[0].userHandle.toLowerCase() == result[1].userHandle.toLowerCase();
      
      expect(hasDuplicateInWindow, isFalse, reason: 'Saturation ignored case-sensitivity');
    });

    test('Edge Case: Duplicate Media URL (Different ID)', () {
      // Setup: Different IDs, but same Media URL
      // This happens when X users retweet or re-upload same media
      final tweets = [
        createTweet('100', 'user_a', mediaUrl: 'same_vid'),
        createTweet('101', 'user_b', mediaUrl: 'other_vid'),
        createTweet('102', 'user_c', mediaUrl: 'same_vid'),
      ];

      // Current saturation ONLY checks handles. 
      // It does not check if the media is the same.
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 5);
      
      print('Media URLs: ${result.map((t) => t.mediaUrls.first).toList()}');
      
      // Check if "same_vid" appears in a 3-item window
      bool hasDuplicateMedia = result[0].mediaUrls.first == result[2].mediaUrls.first;
      expect(hasDuplicateMedia, isFalse, reason: 'Duplicate media found in 3-item window');
    });

    test('Edge Case: Clump larger than lookahead', () {
      // Setup: threshold 1, window 10. 
      // Lookahead in code is windowSize + 5 = 15.
      // If we have 20 user_a and 1 user_b at index 21...
      final tweets = [
        ...List.generate(20, (i) => createTweet('$i', 'user_a')),
        createTweet('99', 'user_b'),
        ...List.generate(10, (i) => createTweet('${i+30}', 'user_c')),
      ];

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 10);
      
      print('Indices 0-5 handles: ${result.sublist(0, 5).map((t) => t.userHandle).toList()}');
      
      // Verify if it managed to pull user_b or user_c up to break the user_a chain
      int userACount = 0;
      for (int i=0; i<5; i++) {
        if (result[i].userHandle == 'user_a') userACount++;
      }
      
      expect(userACount, lessThanOrEqualTo(1), reason: 'Failed to break large clump');
    });
  });
}
