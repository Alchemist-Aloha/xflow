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
      final tweets = [
        createTweet('1', 'user_b'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_c'),
        createTweet('4', 'user_d'),
        createTweet('5', 'user_a'),
      ];

      final playedCounts = {
        'user_a': 0,
        'user_b': 10,
        'user_c': 10,
        'user_d': 10,
      };

      final saturated = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 2);
      final boosted = DiscoveryEngine.applyUnseenSubscriptionBoost(
        saturated, 
        playedCounts,
        lookahead: 5
      );

      bool hasConsecutive = false;
      for(int i=0; i<boosted.length-1; i++) {
        if(boosted[i].userHandle == boosted[i+1].userHandle) hasConsecutive = true;
      }
      
      expect(hasConsecutive, isFalse, reason: 'Boost re-introduced consecutive handles');
    });

    test('Weakness: applySaturation fallback ignores window threshold', () {
      // Setup: Enough variety to actually satisfy the threshold
      // 3 'a's, 6 others. Total 9. Window 2 means 2 items between each 'a'.
      final tweets = [
        createTweet('1', 'user_a'),
        createTweet('2', 'user_a'),
        createTweet('3', 'user_a'),
        createTweet('4', 'user_b'),
        createTweet('5', 'user_c'),
        createTweet('6', 'user_d'),
        createTweet('7', 'user_e'),
        createTweet('8', 'user_f'),
        createTweet('9', 'user_g'),
      ];

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, windowSize: 2);
      
      print('Result handles: ${result.map((t) => t.userHandle).toList()}');
      
      bool hasConsecutive = false;
      for(int i=0; i<result.length-1; i++) {
        if(result[i].userHandle == result[i+1].userHandle) hasConsecutive = true;
      }
      expect(hasConsecutive, isFalse, reason: 'Saturation left consecutive handles');
      
      // Check if threshold is met for 'user_a'
      for (int i=0; i<result.length; i++) {
        if (result[i].userHandle == 'user_a') {
          final start = (i - 2).clamp(0, result.length);
          final window = result.sublist(start, i);
          final count = window.where((t) => t.userHandle == 'user_a').length;
          expect(count, 0, reason: 'Threshold violated for user_a at index $i');
        }
      }
    });
  });
}
