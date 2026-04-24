import '../models/tweet.dart';
import '../utils/app_logger.dart';

/// The core intelligence of XFlow's feed.
/// 
/// Handles interleaving fresh/cached content, promoting new accounts, 
/// and enforcing diversity via saturation thresholds for handles and media.
class DiscoveryEngine {
  /// Interleaves fresh API items and cached items based on a ratio (0.0 to 1.0).
  /// 
  /// [ratio] represents the target percentage of fresh items in the result.
  /// Logic ensures that if we have a 0.3 ratio, roughly 3 out of every 10 items
  /// are from the [fresh] pool, while maintaining relative order within each pool.
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

      // Determine if the next slot should be fresh based on the target ratio
      bool shouldPickFresh = freshIdx < fresh.length &&
          (currentFreshCount < targetFreshCount || cacheIdx >= cached.length);

      if (shouldPickFresh) {
        final item = fresh[freshIdx++];
        result.add(item);
        currentFreshCount++;
      } else if (cacheIdx < cached.length) {
        result.add(cached[cacheIdx++]);
      } else {
        // Fallback for trailing items
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

  /// Ensures handles are compared consistently regardless of '@' prefix or case.
  static String _normalizeHandle(String handle) {
    final trimmed = handle.trim();
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1).toLowerCase();
    }
    return trimmed.toLowerCase();
  }

  /// Promotes tweets from accounts the user has interacted with the least.
  /// 
  /// [playedCountByUser] maps handles to total views.
  /// [lookahead] defines how far down the list we search for a "better" candidate
  /// to swap into the current position.
  /// 
  /// Should be run BEFORE saturation so saturation can "fix" any clumps 
  /// created by the boost.
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

      // Find the account in the lookahead window with the lowest view count
      for (int j = i + 1; j < end; j++) {
        final candScore =
            playedCountByUser[_normalizeHandle(result[j].userHandle)] ?? 0;
        if (candScore < bestScore) {
          bestScore = candScore;
          bestIdx = j;
        }
      }

      // Swap the best candidate into the current position
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

  /// Enforces feed diversity by separating clumps of the same user or media.
  /// 
  /// [threshold] - Max times a handle can appear in [windowSize].
  /// [mediaThreshold] - Max times a specific media URL can appear in [windowSize].
  /// [maxPasses] - Enables multiple sweeps of the list. Essential because 
  /// a swap made to fix index 5 might create a new clump at index 8.
  /// 
  /// The algorithm lookahead search ensures that the item we pull UP to break 
  /// a clump is itself a "valid" fit for the new position.
  static List<Tweet> applySaturation(List<Tweet> tweets,
      {int threshold = 2,
      int mediaThreshold = 1,
      int windowSize = 10,
      int startIndex = 0,
      int maxSaturationSwaps = 1000,
      int maxPasses = 3}) {
    if (tweets.isEmpty) return tweets;
    final result = List<Tweet>.from(tweets);

    int totalSwaps = 0;
    
    // Multi-pass sweep: Subsequent passes resolve clumps created by previous swaps.
    for (int pass = 0; pass < maxPasses; pass++) {
      int passSwaps = 0;
      for (int i = startIndex; i < result.length && totalSwaps < maxSaturationSwaps; i++) {
        final handle = _normalizeHandle(result[i].userHandle);
        final mediaUrl = result[i].mediaUrls.isNotEmpty ? result[i].mediaUrls.first : null;
        
        // Define the sliding window of items preceding the current index
        final start = (i - windowSize + 1).clamp(0, result.length);
        final window = result.sublist(start, i);
        
        // Count occurrences of current item's identity in the preceding window
        final handleCount = window.where((t) => _normalizeHandle(t.userHandle) == handle).length;
        final mediaCount = mediaUrl != null 
            ? window.where((t) => t.mediaUrls.isNotEmpty && t.mediaUrls.first == mediaUrl).length 
            : 0;

        // Hard rule: No consecutive duplicates (even if threshold > 1)
        final isConsecutive = i > 0 && _normalizeHandle(result[i - 1].userHandle) == handle;
        final isMediaConsecutive = i > 0 && mediaUrl != null && 
            result[i - 1].mediaUrls.isNotEmpty && result[i - 1].mediaUrls.first == mediaUrl;

        // If any diversity rule is violated, search forward for a valid swap candidate
        if (handleCount >= threshold || isConsecutive || mediaCount >= mediaThreshold || isMediaConsecutive) {
          int swapIdx = -1;
          final lookahead = windowSize + 10;
          
          for (int j = i + 1; j < result.length && j < i + lookahead; j++) {
            final candHandle = _normalizeHandle(result[j].userHandle);
            final candMedia = result[j].mediaUrls.isNotEmpty ? result[j].mediaUrls.first : null;
            final prevHandle = i > 0 ? _normalizeHandle(result[i - 1].userHandle) : null;
            final prevMedia = i > 0 && result[i - 1].mediaUrls.isNotEmpty ? result[i - 1].mediaUrls.first : null;

            // CRITERIA: Candidate must not be the same as the clump it's breaking,
            // must not be the same as the previous item, AND must not violate its own 
            // saturation rules if moved to index [i].
            if (candHandle != handle && candHandle != prevHandle && (candMedia == null || candMedia != prevMedia)) {
              final candStart = (i - windowSize + 1).clamp(0, result.length);
              final candWindow = result.sublist(candStart, i);
              
              final candHandleCount = candWindow.where((t) => _normalizeHandle(t.userHandle) == candHandle).length;
              final candMediaCount = candMedia != null 
                  ? candWindow.where((t) => t.mediaUrls.isNotEmpty && t.mediaUrls.first == candMedia).length 
                  : 0;

              if (candHandleCount < threshold && candMediaCount < mediaThreshold) {
                swapIdx = j;
                break;
              }
            }
          }

          if (swapIdx != -1) {
            final temp = result[i];
            result[i] = result[swapIdx];
            result[swapIdx] = temp;
            passSwaps++;
            totalSwaps++;
          }
        }
      }
      // If a full pass resulted in zero swaps, the list is perfectly diverse.
      if (passSwaps == 0) break;
    }

    if (totalSwaps > 0) {
      AppLogger.log('Discovery: Applied $totalSwaps saturation swaps (Threshold: $threshold, MediaThreshold: $mediaThreshold, StartIndex: $startIndex)');
    }
    return result;
  }
}
