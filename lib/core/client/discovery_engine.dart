import '../models/tweet.dart';

class DiscoveryEngine {
  /// Interleaves fresh API items and cached items based on a ratio (0.0 to 1.0).
  /// Ratio represents the target percentage of fresh items in the result.
  static List<Tweet> interleave(
      List<Tweet> fresh, List<Tweet> cached, double ratio) {
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
  }) {
    if (tweets.length < 2 || playedCountByUser.isEmpty) return tweets;

    final result = List<Tweet>.from(tweets);

    for (int i = 0; i < result.length - 1; i++) {
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
      }
    }

    return result;
  }

  static List<Tweet> applySaturation(List<Tweet> tweets, {int threshold = 2}) {
    if (tweets.isEmpty) return tweets;
    final result = List<Tweet>.from(tweets);
    const windowSize = 10;

    int totalSwaps = 0;
    const maxTotalSwaps = 1000;

    for (int i = 0; i < result.length && totalSwaps < maxTotalSwaps; i++) {
      final handle = result[i].userHandle;
      final start = (i - windowSize + 1).clamp(0, result.length);
      final window = result.sublist(start, i);
      final count = window.where((t) => t.userHandle == handle).length;

      final isConsecutive = i > 0 && result[i - 1].userHandle == handle;

      if (count >= threshold || isConsecutive) {
        int swapIdx = -1;

        // Try to find someone who is NOT the same as previous AND doesn't violate saturation
        for (int j = i + 1; j < result.length; j++) {
          final candHandle = result[j].userHandle;
          final prevHandle = i > 0 ? result[i - 1].userHandle : null;

          if (candHandle != handle && candHandle != prevHandle) {
            final candCount =
                window.where((t) => t.userHandle == candHandle).length;
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

        // Last resort: anyone different from current
        if (swapIdx == -1) {
          for (int j = i + 1; j < result.length; j++) {
            if (result[j].userHandle != handle) {
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
          i--;
        } else if (isConsecutive || count >= threshold) {
          // TRAPPED! No candidates forward. Try to find a spot backwards that won't break things.
          for (int k = i - 1; k > 0; k--) {
            final targetHandle = result[k].userHandle;
            if (targetHandle != handle) {
              // Can we swap result[i] and result[k]?
              // New result[k] would be handle (@A)
              // Check if result[k-1] and result[k+1] are @A
              final prevOk = result[k - 1].userHandle != handle;
              final nextOk =
                  k + 1 < result.length && result[k + 1].userHandle != handle;

              if (prevOk && nextOk) {
                // Also check saturation at k
                final kStart = (k - windowSize + 1).clamp(0, result.length);
                final kWindow = result.sublist(kStart, k);
                final kCount =
                    kWindow.where((t) => t.userHandle == handle).length;

                if (kCount < threshold) {
                  final temp = result[i];
                  result[i] = result[k];
                  result[k] = temp;
                  totalSwaps++;
                  // Don't i-- here as it might cause loops, but the swap fixed i's consecutive/count usually
                  break;
                }
              }
            }
          }
        }
      }
    }
    return result;
  }
}
