import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:xflow/core/client/discovery_engine.dart';

void main() {
  group('DiscoveryEngine.interleave', () {
    test('interleaves fresh and cached items based on ratio', () {
      final fresh = List.generate(20, (i) => Tweet(
        id: 'f$i', 
        text: 'fresh', 
        userHandle: 'u', 
        mediaUrls: [],
      ));
      final cached = List.generate(20, (i) => Tweet(
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
      final cached = [Tweet(id: 'c1', text: 'cache', userHandle: 'u', mediaUrls: [])];
      
      final result = DiscoveryEngine.interleave(fresh, cached, 0.5);
      expect(result.length, 1);
      expect(result.first.id, 'c1');
    });
  });

  group('DiscoveryEngine.applySaturation', () {
    test('enforces saturation threshold by swapping items', () {
      final tweets = [
        Tweet(id: '1', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '3', userHandle: 'user_a', text: '', mediaUrls: []), // Third one from user_a
        Tweet(id: '4', userHandle: 'user_b', text: '', mediaUrls: []),
      ];
      
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 2);
      
      expect(result[0].userHandle, 'user_a');
      expect(result[1].userHandle, 'user_a');
      expect(result[2].userHandle, 'user_b'); // Swapped with user_b
      expect(result[3].userHandle, 'user_a'); // The third user_a item pushed to the end
    });

    test('does nothing if under threshold', () {
      final tweets = [
        Tweet(id: '1', userHandle: 'user_a', text: '', mediaUrls: []),
        Tweet(id: '2', userHandle: 'user_b', text: '', mediaUrls: []),
      ];
      final result = DiscoveryEngine.applySaturation(tweets, threshold: 2);
      expect(result, tweets);
    });
  });
}
