import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../../core/database/repository.dart';
import '../../core/client/discovery_engine.dart';
import '../../core/utils/app_logger.dart';
import '../settings/settings_provider.dart';
import '../player/player_pool_provider.dart';

final twitterClientProvider = Provider((ref) => TwitterClient());

class FeedState {
  final List<Tweet> tweets;
  final String? cursorBottom;
  final bool isLoadingMore;
  final bool isRefreshing;

  FeedState({
    required this.tweets,
    this.cursorBottom,
    this.isLoadingMore = false,
    this.isRefreshing = false,
  });

  FeedState copyWith({
    List<Tweet>? tweets,
    String? cursorBottom,
    bool? isLoadingMore,
    bool? isRefreshing,
  }) {
    return FeedState(
      tweets: tweets ?? this.tweets,
      cursorBottom: cursorBottom ?? this.cursorBottom,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class FeedNotifier extends AutoDisposeAsyncNotifier<FeedState> {
  Future<int> _resolveSyncBatchSize(SettingsState settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getInt('syncBatchSize');
      return persisted ?? settings.syncBatchSize;
    } catch (_) {
      return settings.syncBatchSize;
    }
  }

  List<Tweet> _runDiscoveryPipeline(
    List<Tweet> freshPool,
    List<Tweet> localPool,
    SettingsState settings,
    Map<String, int> playedByUser, {
    int protectedIndex = 0,
    List<Tweet> currentTweets = const [],
  }) {
    final head = currentTweets.take(protectedIndex).toList();
    final headIds = head.map((t) => t.id).toSet();
    final headMedia = head
        .where((t) => t.mediaUrls.isNotEmpty)
        .map((t) => t.mediaUrls.first)
        .toSet();

    // Initialize seen sets using a sliding window of already visible tweets
    final dedupeWindow = currentTweets.length >
            settings.mediaDeduplicationWindow
        ? currentTweets
            .sublist(currentTweets.length - settings.mediaDeduplicationWindow)
        : currentTweets;

    final seenIds = {...headIds, ...dedupeWindow.map((t) => t.id)};
    final seenMediaUrls = {
      ...headMedia,
      ...dedupeWindow
          .where((t) => t.mediaUrls.isNotEmpty)
          .map((t) => t.mediaUrls.first)
    };

    List<Tweet> deduplicate(List<Tweet> pool) {
      return pool.where((t) {
        if (seenIds.contains(t.id)) return false;
        if (t.mediaUrls.isNotEmpty &&
            seenMediaUrls.contains(t.mediaUrls.first)) {
          return false;
        }
        seenIds.add(t.id);
        if (t.mediaUrls.isNotEmpty) seenMediaUrls.add(t.mediaUrls.first);
        return true;
      }).toList();
    }

    final uniqueFresh = deduplicate(freshPool)..shuffle();
    final uniqueLocal = deduplicate(localPool)..shuffle();

    final interleaved = DiscoveryEngine.interleave(
        uniqueFresh, uniqueLocal, settings.freshMixRatio);

    var processed = [...head, ...interleaved];

    if (settings.unseenSubscriptionBoost) {
      processed = DiscoveryEngine.applyUnseenSubscriptionBoost(
        processed,
        playedByUser,
        lookahead: settings.unseenBoostLookahead,
        startIndex: head.length,
      );
    }

    processed = DiscoveryEngine.applySaturation(
      processed,
      threshold: settings.saturationThreshold,
      mediaThreshold: settings.mediaSaturationThreshold,
      windowSize: settings.saturationWindow,
      startIndex: head.length,
      maxSaturationSwaps: settings.maxSaturationSwaps,
      maxPasses: settings.maxSaturationPasses,
    );

    return processed;
  }

  @override
  FutureOr<FeedState> build() async {
    final settings = ref.watch(settingsProvider);

    debugPrint(
        'XFLOW: Building FeedNotifier. fetchStrategy: ${settings.fetchStrategy}');

    try {
      // Stage 1: Immediate local candidate retrieval
      final localPool = await Repository.getCachedMediaCandidates(
        settings.loadBatchSize * settings.dbCandidateMultiplier,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );
      final localTagged =
          localPool.map((t) => t.copyWith(source: 'Cache')).toList();
      AppLogger.log(
          'XFLOW: Cold start: Retrieved ${localPool.length} local candidates');

      // EARLY MEDIA WARMUP
      if (localTagged.isNotEmpty) {
        final pool = ref.read(playerPoolProvider.notifier);
        for (int i = 0; i < localTagged.length && i < 3; i++) {
          final tweet = localTagged[i];
          if (tweet.isVideo && tweet.mediaUrls.isNotEmpty) {
            pool.warmup(tweet.id, tweet.mediaUrls.first);
          }
        }
      }

      // TRIGGER BACKGROUND SYNC
      if (settings.isInitialized) {
        Future.delayed(Duration.zero, () => _refreshInBackground());
      }

      return FeedState(
        tweets: localTagged,
        cursorBottom: null,
        isRefreshing: localTagged.isEmpty,
      );
    } catch (e, st) {
      debugPrint('XFLOW: Error in build(): $e\n$st');
      return FeedState(tweets: [], isRefreshing: false);
    }
  }

  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null || currentState.isRefreshing) return;

    state = AsyncData(currentState.copyWith(isRefreshing: true));
    await _refreshInBackground(resetHead: true);
  }

  Future<void> _refreshInBackground({bool resetHead = false}) async {
    if (!ref.exists(feedNotifierProvider)) return;

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);
    final syncBatchSize = await _resolveSyncBatchSize(settings);

    debugPrint('XFLOW: Background refresh started');

    try {
      // 1. Fetch from API
      final TweetResponse freshResponse;
      if (settings.fetchStrategy == FeedSort.videomixer) {
        freshResponse = await client.fetchVideoMixer(
          count: settings.timelineBatchSize,
          filters: settings.filters,
        );
      } else if (settings.fetchStrategy == FeedSort.algorithmic) {
        freshResponse = await client.fetchAlgorithmicTimeline(
          count: settings.timelineBatchSize,
          filters: settings.filters,
        );
      } else if (settings.fetchStrategy == FeedSort.chronological) {
        freshResponse = await client.fetchChronologicalTimeline(
          count: settings.timelineBatchSize,
          filters: settings.filters,
        );
      } else {
        freshResponse = await client.fetchSubscribedMedia(
          sort: settings.fetchStrategy,
          filters: settings.filters,
          subBatchSize: syncBatchSize,
          loadBatchSize: settings.initialSyncCount,
          cooldownMinutes: settings.cooldownDuration,
          strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
          includeNativeRetweets: settings.includeNativeRetweets,
          useChunkedSubscriptions: settings.useChunkedSubscriptions,
          minFaves: settings.minFavesFilter,
        );
      }

      final freshPool = freshResponse.tweets;
      final freshTagged =
          freshPool.map((t) => t.copyWith(source: 'API')).toList();

      debugPrint(
          'XFLOW: Background refresh returned ${freshPool.length} fresh tweets');

      if (freshPool.isNotEmpty) {
        await Repository.insertCachedMedia(freshPool);
      }

      // 2. Fetch local pool (now including fresh items)
      final localPool = await Repository.getCachedMediaCandidates(
        settings.loadBatchSize * settings.dbCandidateMultiplier,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );
      final localTagged =
          localPool.map((t) => t.copyWith(source: 'Cache')).toList();

      final currentAsync = ref.read(feedNotifierProvider);
      if (currentAsync.hasValue) {
        final current = currentAsync.value!;

        final playedByUser = settings.unseenSubscriptionBoost
            ? await Repository.getPlayedCountsByUser()
            : const <String, int>{};

        // PROTECT THE ACTIVE VIDEO: If user is at index 0, protect index 0 from being swapped.
        // We protect up to 2 items to ensure the "next" item also doesn't jump unexpectedly.
        final processed = _runDiscoveryPipeline(
          freshTagged,
          localTagged,
          settings,
          playedByUser,
          protectedIndex: resetHead ? 0 : 2,
          currentTweets: resetHead ? [] : current.tweets,
        );

        state = AsyncData(current.copyWith(
          tweets: processed,
          cursorBottom: freshResponse.cursorBottom,
          isRefreshing: false,
        ));
        debugPrint(
            'XFLOW: Feed state updated from background refresh. Total: ${processed.length}');
      }
    } catch (e) {
      debugPrint('XFLOW: Background refresh error: $e');
      final currentAsync = ref.read(feedNotifierProvider);
      if (currentAsync.hasValue) {
        state = AsyncData(currentAsync.value!.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoadingMore) return;

    final settings = ref.read(settingsProvider);
    final syncBatchSize = await _resolveSyncBatchSize(settings);

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final seenIds = state.value!.tweets.map((t) => t.id).toSet();

      // Use dynamic deduplication window from settings
      final dedupeWindow = state.value!.tweets.length >
              settings.mediaDeduplicationWindow
          ? state.value!.tweets.sublist(
              state.value!.tweets.length - settings.mediaDeduplicationWindow)
          : state.value!.tweets;

      final seenMedia = dedupeWindow
          .where((t) => t.mediaUrls.isNotEmpty)
          .map((t) => t.mediaUrls.first)
          .toSet();

      List<Tweet> allNewTweets = [];
      String? currentCursor = state.value!.cursorBottom;
      final seenCursors = <String>{};
      int apiRetries = 0;
      int chunkRotations = 0;

      while (allNewTweets.length < settings.minNewTweetsThreshold &&
          apiRetries < settings.apiRetryLimit &&
          chunkRotations < settings.chunkRotationLimit) {
        // 1. Try to fetch from DB first (refresh pool)
        final dbCandidates = await Repository.getCachedMediaCandidates(
          settings.loadBatchSize * settings.dbCandidateMultiplier,
          avoidWatchedContent: settings.avoidWatchedContent,
          filters: settings.filters,
        );

        var localNew = dbCandidates.where((t) {
          return !seenIds.contains(t.id) &&
              (t.mediaUrls.isEmpty || !seenMedia.contains(t.mediaUrls.first));
        }).toList();

        if (localNew.isNotEmpty) {
          allNewTweets.addAll(localNew);
          if (allNewTweets.length >= settings.minNewTweetsThreshold) break;
        }

        // 2. Hit the API
        final client = ref.read(twitterClientProvider);
        if (currentCursor != null) seenCursors.add(currentCursor);

        final TweetResponse response;
        if (settings.fetchStrategy == FeedSort.videomixer) {
          response = await client.fetchVideoMixer(
            cursor: currentCursor,
            count: settings.timelineBatchSize,
            filters: settings.filters,
          );
        } else if (settings.fetchStrategy == FeedSort.algorithmic) {
          response = await client.fetchAlgorithmicTimeline(
            cursor: currentCursor,
            count: settings.timelineBatchSize,
            filters: settings.filters,
          );
        } else if (settings.fetchStrategy == FeedSort.chronological) {
          response = await client.fetchChronologicalTimeline(
            cursor: currentCursor,
            count: settings.timelineBatchSize,
            filters: settings.filters,
          );
        } else {
          response = await client.fetchSubscribedMedia(
            cursor: currentCursor,
            sort: settings.fetchStrategy,
            filters: settings.filters,
            subBatchSize: syncBatchSize,
            loadBatchSize: settings.loadBatchSize,
            cooldownMinutes: settings.cooldownDuration,
            strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
            includeNativeRetweets: settings.includeNativeRetweets,
            useChunkedSubscriptions: settings.useChunkedSubscriptions,
            minFaves: settings.minFavesFilter,
            maxQueryLength: settings.maxQueryLength,
            timeoutSeconds: settings.apiTimeoutSeconds,
          );
        }

        final freshUnique = response.tweets.where((t) {
          return !seenIds.contains(t.id) &&
              (t.mediaUrls.isEmpty || !seenMedia.contains(t.mediaUrls.first));
        }).toList();

        if (response.tweets.isNotEmpty) {
          await Repository.insertCachedMedia(response.tweets);
        }

        allNewTweets.addAll(freshUnique);
        apiRetries++;

        // Handle Pagination vs Rotation
        if (response.cursorBottom != null &&
            response.cursorBottom != currentCursor &&
            !seenCursors.contains(response.cursorBottom!)) {
          currentCursor = response.cursorBottom;
        } else {
          // Chunk exhausted or stuck cursor
          AppLogger.log(
              'XFLOW: Chunk exhausted or stuck cursor. Rotating to next subscription chunk.');
          currentCursor = null;
          chunkRotations++;
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (allNewTweets.length < settings.minNewTweetsThreshold) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (allNewTweets.isEmpty) {
        state = AsyncData(state.value!.copyWith(isLoadingMore: false));
        return;
      }

      // Shuffle candidates BEFORE taking the batch to improve diversity
      allNewTweets.shuffle();

      final finalNewTweets = allNewTweets
          .take(settings.loadBatchSize)
          .map((t) => t.copyWith(source: t.source ?? 'Mixed'))
          .toList();

      var combined = [...state.value!.tweets, ...finalNewTweets];

      // Apply diversity enforcement to the new tail
      combined = DiscoveryEngine.applySaturation(
        combined,
        threshold: settings.saturationThreshold,
        mediaThreshold: settings.mediaSaturationThreshold,
        windowSize: settings.saturationWindow,
        startIndex: state.value!.tweets.length,
        maxSaturationSwaps: settings.maxSaturationSwaps,
        maxPasses: settings.maxSaturationPasses,
      );

      state = AsyncData(state.value!.copyWith(
        tweets: combined,
        cursorBottom: currentCursor,
        isLoadingMore: false,
      ));
      debugPrint(
          'XFLOW: fetchMore complete. Added ${finalNewTweets.length} tweets. Total: ${combined.length}');
    } catch (e, st) {
      debugPrint('Error fetching more: $e\n$st');
      state = AsyncData(state.value!.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String tweetId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final tweetIndex = currentState.tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex == -1) return;

    final tweet = currentState.tweets[tweetIndex];
    final newIsLiked = !tweet.isLiked;
    final newFavoriteCount = tweet.favoriteCount + (newIsLiked ? 1 : -1);

    // Optimistic UI Update
    final updatedTweet = tweet.copyWith(
      isLiked: newIsLiked,
      favoriteCount: newFavoriteCount >= 0 ? newFavoriteCount : 0,
    );

    final updatedTweets = List<Tweet>.from(currentState.tweets);
    updatedTweets[tweetIndex] = updatedTweet;
    state = AsyncData(currentState.copyWith(tweets: updatedTweets));

    // API Call
    final client = ref.read(twitterClientProvider);
    final success = newIsLiked
        ? await client.favoriteTweet(tweetId)
        : await client.unfavoriteTweet(tweetId);

    if (!success) {
      // Revert on failure
      final currentAsync = ref.read(feedNotifierProvider);
      if (currentAsync.hasValue) {
        final latestState = currentAsync.value!;
        final idx = latestState.tweets.indexWhere((t) => t.id == tweetId);
        if (idx != -1) {
          final revertedTweets = List<Tweet>.from(latestState.tweets);
          revertedTweets[idx] = tweet; // original tweet
          state = AsyncData(latestState.copyWith(tweets: revertedTweets));
        }
      }
      AppLogger.log('XFLOW: Failed to toggle like for $tweetId, reverted.');
    } else {
      AppLogger.log(
          'XFLOW: Successfully toggled like for $tweetId to $newIsLiked');
    }
  }
}

final feedNotifierProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, FeedState>(
        () => FeedNotifier());

// Legacy support for parts of the code that still expect feedProvider
final feedProvider = Provider.autoDispose<AsyncValue<List<Tweet>>>((ref) {
  final asyncState = ref.watch(feedNotifierProvider);
  return asyncState.whenData((state) => state.tweets);
});
