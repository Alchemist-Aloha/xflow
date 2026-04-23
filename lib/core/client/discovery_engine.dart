import '../models/tweet.dart';

class DiscoveryEngine {
  /// Interleaves fresh API items and cached items based on a ratio (0.0 to 1.0).
  /// Ratio represents the target percentage of fresh items in the result.
  static List<Tweet> interleave(List<Tweet> fresh, List<Tweet> cached, double ratio) {
    final result = <Tweet>[];
    int freshIdx = 0;
    int cacheIdx = 0;
    
    // Track fresh items in a set for O(1) lookups
    final freshIds = fresh.map((t) => t.id).toSet();
    int currentFreshCount = 0;

    while (freshIdx < fresh.length || cacheIdx < cached.length) {
      int nextCount = result.length + 1;
      int targetFreshCount = (nextCount * ratio).floor();

      bool shouldPickFresh = freshIdx < fresh.length && 
          (currentFreshCount < targetFreshCount || cacheIdx >= cached.length);

      if (shouldPickFresh) {
        final item = fresh[freshIdx++];
        result.add(item);
        currentFreshCount++;
      } else if (cacheIdx < cached.length) {
        result.add(cached[cacheIdx++]);
      } else {
        if (freshIdx < fresh.length) {
          result.add(fresh[freshIdx++]);
          currentFreshCount++;
        } else {
          break;
        }
      }
    }
    return result;
  }

  static bool _isFresh(Tweet tweet, List<Tweet> freshSource) {
    // In practice, we'd check if the ID exists in the fresh list.
    // For the engine, we can just check reference or ID.
    return freshSource.any((t) => t.id == tweet.id);
  }

  /// Swaps items to prevent the same user from appearing more than [threshold] times
  /// within a sliding window of 10 items.
  static List<Tweet> applySaturation(List<Tweet> tweets, {int threshold = 2}) {
    if (tweets.isEmpty) return tweets;
    final result = List<Tweet>.from(tweets);
    const windowSize = 10;
    
    // Safety: don't loop forever.
    for (int i = 0; i < result.length; i++) {
      final start = (i - windowSize + 1).clamp(0, result.length);
      final window = result.sublist(start, i + 1);
      final handle = result[i].userHandle;
      
      final count = window.where((t) => t.userHandle == handle).length;

      if (count > threshold) {
        // Find a candidate to swap with from further down
        int swapIdx = -1;
        for (int j = i + 1; j < result.length; j++) {
          if (result[j].userHandle != handle) {
            // Check if swapping would violate saturation for the candidate at its new position
            // For simplicity, we just swap with the first different user we find.
            swapIdx = j;
            break;
          }
        }

        if (swapIdx != -1) {
          final temp = result[i];
          result[i] = result[swapIdx];
          result[swapIdx] = temp;
          // We don't i-- here to avoid potential infinite loops if threshold is too low.
          // The next iteration will check i+1.
        }
      }
    }
    return result;
  }
}
