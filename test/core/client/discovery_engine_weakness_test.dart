import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/discovery_engine.dart';
import 'package:xflow/core/models/tweet.dart';

void main() {
  Tweet createTweet(String id, String handle) {
    return Tweet(
      id: id,
      userHandle: handle,
      text: 'Tweet $id',
      mediaUrls: ['url_$id'],
      createdAt: DateTime.now(),
    );
  }

  group('DiscoveryEngine Weakness Tests', () {
    test('Weakness: applyUnseenSubscriptionBoost violates saturation', () {
      // Setup: 4 items, already saturated for 'user_a'
      // Index 0: user_b, Index 1: user_a, Index 2: user_c, Index 3: user_a (Unseen)
      // Saturation (threshold 1) would want them separated.
      final tweets = [
        createTweet('1', 'user_b'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_c'),
        createTweet('4', 'user_a'),
      ];

      // user_a is 'unseen' (played count 0), others have played count 10
      final playedCounts = {
        'user_a': 0,
        'user_b': 10,
        'user_c': 10,
      };

      // 1. Apply saturation first (threshold 1, window 2)
      final saturated = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 2);
      
      // Verify saturation worked (it should have moved 4 away from 2)
      // Expectation: [user_b, user_a, user_c, user_a] -> [user_b, user_a, user_c, user_a] wait
      // Actually with threshold 1, window 2, [user_a, user_c, user_a] is a violation at index 3.
      
      // 2. Apply boost
      final boosted = DiscoveryEngine.applyUnseenSubscriptionBoost(
        saturated, 
        playedCounts,
        lookahead: 5
      );

      // WEAKNESS: Boost might pull 'user_a' (index 3) to index 0 or 2, 
      // potentially putting it next to the other 'user_a' at index 1.
      
      bool hasConsecutive = false;
      for(int i=0; i<boosted.length-1; i++) {
        if(boosted[i].userHandle == boosted[i+1].userHandle) hasConsecutive = true;
      }
      
      print('Boosted handles: ${boosted.map((t) => t.userHandle).toList()}');
      expect(hasConsecutive, isFalse, reason: 'Boost re-introduced consecutive handles');
    });

    test('Weakness: applySaturation fallback ignores window threshold', () {
      // Setup: Many user_a, one user_b at the end.
      final tweets = [
        createTweet('1', 'user_a'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_a'),
        createTweet('4', 'user_b'),
      ];

      // threshold 1 means we only want 1 'user_a' per window.
      // applySaturation will try to swap index 1 (user_a) with index 3 (user_b).
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 10);
      
      // Result: [user_a, user_b, user_a, user_a]
      // At index 2, it sees 'user_a'. Window [user_a, user_b, user_a] has two 'user_a'.
      // It looks for a swap after index 2. None found.
      // WEAKNESS: It leaves the violation instead of attempting a multi-pass or 
      // flagging it.
      
      final handleCountAtEnd = result.sublist(1).where((t) => t.userHandle == 'user_a').length;
      print('Result handles: ${result.map((t) => t.userHandle).toList()}');
      // This is expected to fail if the weakness exists
      expect(handleCountAtEnd, lessThanOrEqualTo(1), reason: 'Saturation failed to separate items');
    });
  });
}
