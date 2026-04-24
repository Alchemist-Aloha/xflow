import '../models/tweet.dart';
import '../utils/app_logger.dart';

class DiscoveryEngine {
  /// Interleaves fresh API items and cached items based on a ratio (0.0 to 1.0).
  /// Ratio represents the target percentage of fresh items in the result.
  static List<Tweet> interleave(
      List<Tweet> fresh, List<Tweet> cached, double ratio) {
    AppLogger.log(
        'Discovery: Interleaving ${fresh.length} fresh and ${cached.length} cached items with ratio $ratio');
    final result = <Tweet>[];
    int freshIdx = 0;
    int cacheIdx = 0;

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
    AppLogger.log('Discovery: Interleaving complete. Total: ${result.length}');
    return result;
  }

  static String _normalizeHandle(String handle) {
    final trimmed = handle.trim();
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1).toLowerCase();
    }
    return trimmed.toLowerCase();
  }

  /// Stage 4: Slightly promotes tweets from less-watched accounts.
  ///
  /// The boost is intentionally local (lookahead window) to avoid destroying
  /// freshness/interleave ordering while still improving account discovery.
  static List<Tweet> applyUnseenSubscriptionBoost(
    List<Tweet> tweets,
    Map<String, int> playedCountByUser, {
    int lookahead = 6,
    int startIndex = 0,
  }) {
    if (tweets.length < 2 || playedCountByUser.isEmpty) return tweets;

    final result = List<Tweet>.from(tweets);
    int boosts = 0;

    for (int i = startIndex; i < result.length - 1; i++) {
      final end = (i + lookahead).clamp(i + 1, result.length);
      int bestIdx = i;
      int bestScore =
          playedCountByUser[_normalizeHandle(result[i].userHandle)] ?? 0;

      for (int j = i + 1; j < end; j++) {
        final candScore =
            playedCountByUser[_normalizeHandle(result[j].userHandle)] ?? 0;
        if (candScore < bestScore) {
          bestScore = candScore;
          bestIdx = j;
        }
      }

      if (bestIdx != i) {
        final temp = result[i];
        result[i] = result[bestIdx];
        result[bestIdx] = temp;
        boosts++;
      }
    }

    if (boosts > 0) {
      AppLogger.log('Discovery: Applied $boosts unseen subscription boosts (Lookahead: $lookahead, StartIndex: $startIndex)');
    }
    return result;
  }

  static List<Tweet> applySaturation(List<Tweet> tweets,
      {int threshold = 2,
      int windowSize = 10,
      int startIndex = 0,
      int maxSaturationSwaps = 1000}) {
    if (tweets.isEmpty) return tweets;
    final result = List<Tweet>.from(tweets);

    int totalSwaps = 0;

    for (int i = startIndex; i < result.length && totalSwaps < maxSaturationSwaps; i++) {
      final handle = _normalizeHandle(result[i].userHandle);
      final start = (i - windowSize + 1).clamp(0, result.length);
      final window = result.sublist(start, i);
      final count = window.where((t) => _normalizeHandle(t.userHandle) == handle).length;

      final isConsecutive = i > 0 && _normalizeHandle(result[i - 1].userHandle) == handle;

      if (count >= threshold || isConsecutive) {
        int swapIdx = -1;

        // Try to find someone who is NOT the same as previous AND doesn't violate saturation
        // Use a dynamic lookahead based on windowSize for better stability
        final lookahead = windowSize + 5;
        for (int j = i + 1; j < result.length && j < i + lookahead; j++) {
          final candHandle = _normalizeHandle(result[j].userHandle);
          final prevHandle = i > 0 ? _normalizeHandle(result[i - 1].userHandle) : null;

          if (candHandle != handle && candHandle != prevHandle) {
            // Check if swapping candHandle to position i would violate its own saturation
            final candStart = (i - windowSize + 1).clamp(0, result.length);
            final candWindow = result.sublist(candStart, i);
            final candCount = candWindow.where((t) => _normalizeHandle(t.userHandle) == candHandle).length;
            
            if (candCount < threshold) {
              swapIdx = j;
              break;
            }
          }
        }

        // Fallback: anyone different from current AND previous
        if (swapIdx == -1) {
          for (int j = i + 1; j < result.length; j++) {
            final candHandle = result[j].userHandle;
            final prevHandle = i > 0 ? result[i - 1].userHandle : null;
            if (candHandle != handle && candHandle != prevHandle) {
              swapIdx = j;
              break;
            }
          }
        }

        if (swapIdx != -1) {
          final temp = result[i];
          result[i] = result[swapIdx];
          result[swapIdx] = temp;
          totalSwaps++;
          // We don't i-- anymore to avoid loops. The current i is now a better candidate.
        }
      }
    }
    if (totalSwaps > 0) {
      AppLogger.log('Discovery: Applied $totalSwaps saturation swaps (Window: $windowSize, Threshold: $threshold, StartIndex: $startIndex)');
    }
    return result;
  }

}

