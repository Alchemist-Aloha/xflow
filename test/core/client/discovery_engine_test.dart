import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:xflow/core/client/discovery_engine.dart';

void main() {
  group('DiscoveryEngine.interleave', () {
    test('interleaves fresh and cached items based on ratio', () {
      final fresh = List.generate(
          20,
          (i) => Tweet(
                id: 'f$i',
                text: 'fresh',
                userHandle: 'u',
                mediaUrls: [],
              ));
      final cached = List.generate(
          20,
          (i) => Tweet(
                id: 'c$i',
                text: 'cache',
                userHandle: 'u',
                mediaUrls: [],
              ));

      // 0.3 ratio -> ~3 fresh items per 10 items
      final result = DiscoveryEngine.interleave(fresh, cached, 0.3);

      expect(result.length, 40);

      final first10 = result.take(10).toList();
      final freshInFirst10 = first10.where((t) => t.id.startsWith('f')).length;
      final cachedInFirst10 = first10.where((t) => t.id.startsWith('c')).length;

      expect(freshInFirst10, 3);
      expect(cachedInFirst10, 7);
    });

    test('handles empty buckets gracefully', () {
      final fresh = <Tweet>[];
      final cached = [
        Tweet(id: 'c1', text: 'cache', userHandle: 'u', mediaUrls: [])
      ];

      final result = DiscoveryEngine.interleave(fresh, cached, 0.5);
      expect(result.length, 1);
      expect(result.first.id, 'c1');
    });
  });

  group('DiscoveryEngine.applySaturation', () {
    test('enforces saturation threshold and avoids consecutive repeats', () {
      final tweets = [
        Tweet(id: '1', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '3', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '4', userHandle: 'user_b', text: '', mediaUrls: []),
      ];

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 2);

      expect(result[0].userHandle, 'user_a');
      expect(result[1].userHandle,
          'user_b'); // Swapped to avoid consecutive user_a
      expect(result[2].userHandle, 'user_a');
      expect(result[3].userHandle,
          'user_a'); // Two user_a at the end is okay because no one left to swap
    });

    test('handles clumps by spreading them out', () {
      final tweets = [
        Tweet(id: '1', userHandle: '@A', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: '@A', text: '', mediaUrls: []),
        Tweet(id: '3', userHandle: '@B', text: '', mediaUrls: []),
        Tweet(id: '4', userHandle: '@B', text: '', mediaUrls: []),
        Tweet(id: '5', userHandle: '@C', text: '', mediaUrls: []),
        Tweet(id: '6', userHandle: '@C', text: '', mediaUrls: []),
      ];

      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1);

      for (int i = 0; i < result.length - 1; i++) {
        expect(result[i].userHandle, isNot(result[i + 1].userHandle),
            reason: 'Failed at index $i');
      }
    });

    test('does nothing if under threshold and not consecutive', () {
      final tweets = [
        Tweet(id: '1', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: 'user_b', text: '', mediaUrls: []),
      ];
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 2);
      expect(result, tweets);
    });
  });

  group('DiscoveryEngine.applyUnseenSubscriptionBoost', () {
    test('promotes less-watched accounts within local window', () {
      final tweets = [
        Tweet(id: '1', userHandle: '@heavy', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: '@heavy', text: '', mediaUrls: []),
        Tweet(id: '3', userHandle: '@light', text: '', mediaUrls: []),
        Tweet(id: '4', userHandle: '@new', text: '', mediaUrls: []),
      ];

      final boosted = DiscoveryEngine.applyUnseenSubscriptionBoost(
        tweets,
        {'heavy': 50, 'light': 5, 'new': 0},
        lookahead: 4,
      );

      // Expect a lower-played account to surface ahead of heavy users.
      expect(boosted.first.userHandle, anyOf('@light', '@new'));
    });

    test('keeps order when no play stats are available', () {
      final tweets = [
        Tweet(id: '1', userHandle: '@a', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: '@b', text: '', mediaUrls: []),
      ];

      final boosted = DiscoveryEngine.applyUnseenSubscriptionBoost(tweets, {});
      expect(boosted, tweets);
    });

    test('protects items before startIndex from being swapped', () {
      final tweets = [
        Tweet(id: '1', userHandle: '@heavy', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: '@light', text: '', mediaUrls: []),
      ];

      // Even though @light is "better", it won't be boosted to index 0 if startIndex is 1
      final boosted = DiscoveryEngine.applyUnseenSubscriptionBoost(
        tweets,
        {'heavy': 100, 'light': 0},
        startIndex: 1,
      );

      expect(boosted[0].userHandle, '@heavy');
    });
  });

  group('DiscoveryEngine startIndex protection', () {
    test('applySaturation does not swap items before startIndex', () {
      final tweets = [
        Tweet(id: '1', userHandle: '@A', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: '@A', text: '', mediaUrls: []), // Consecutive!
        Tweet(id: '3', userHandle: '@B', text: '', mediaUrls: []),
      ];

      // Normally index 1 would be swapped. If we protect index 1, it stays.
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 1, startIndex: 2);
      
      expect(result[0].userHandle, '@A');
      expect(result[1].userHandle, '@A');
      expect(result[2].userHandle, '@B');
    });
  });
}
