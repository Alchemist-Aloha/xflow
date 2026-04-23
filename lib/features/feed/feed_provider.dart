import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../../core/database/repository.dart';
import '../../core/client/discovery_engine.dart';
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
  @override
  FutureOr<FeedState> build() async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    
    debugPrint('XFLOW: Building FeedNotifier. fetchStrategy: ${settings.fetchStrategy}');

    try {
      // 1. Try to get unplayed media from local DB
      List<Tweet> tweets = await Repository.getUnplayedCachedMedia(
        settings.loadBatchSize * 3,
        filters: settings.filters,
      );

      debugPrint('XFLOW: Local pool size: ${tweets.length}');

      // 2. If DB is empty, we MUST fetch from API now to avoid blank screen on first launch
      if (tweets.isEmpty) {
        debugPrint('XFLOW: DB empty, performing initial sync...');
        final response = await client.fetchSubscribedMedia(
          sort: settings.fetchStrategy,
          filters: settings.filters,
          subBatchSize: settings.syncBatchSize,
          loadBatchSize: settings.initialSyncCount,
          cooldownMinutes: settings.cooldownDuration,
        );
        tweets = response.tweets;
        debugPrint('XFLOW: Initial sync returned ${tweets.length} tweets');
        if (tweets.isNotEmpty) {
          await Repository.insertCachedMedia(tweets);
        }
      } else {
        // DB not empty, trigger a background refresh to get fresher content
        debugPrint('XFLOW: DB has content, triggering background refresh');
        Future.delayed(Duration.zero, () => _refreshInBackground());
      }

      var processed = DiscoveryEngine.applySaturation(tweets, threshold: settings.saturationThreshold);

      // Warm up the player pool
      final pool = ref.read(playerPoolProvider.notifier);
      for (int i = 0; i < processed.length && i < 3; i++) {
        final tweet = processed[i];
        if (tweet.isVideo && tweet.mediaUrls.isNotEmpty) {
          pool.warmup(tweet.id, tweet.mediaUrls.first);
        }
      }
      
      return FeedState(
        tweets: processed,
        cursorBottom: null,
        isRefreshing: tweets.isEmpty, // Only refreshing if we started with nothing
      );
    } catch (e, st) {
      debugPrint('XFLOW: Error in build(): $e\n$st');
      return FeedState(tweets: [], isRefreshing: false);
    }
  }

  Future<void> _refreshInBackground() async {
    if (!ref.exists(feedNotifierProvider)) return;

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    debugPrint('XFLOW: Background refresh started');

    try {
      final freshResponse = await client.fetchSubscribedMedia(
        sort: settings.fetchStrategy,
        filters: settings.filters,
        subBatchSize: settings.syncBatchSize,
        loadBatchSize: settings.initialSyncCount,
        cooldownMinutes: settings.cooldownDuration,
      );

      final freshPool = freshResponse.tweets;
      debugPrint('XFLOW: Background refresh returned ${freshPool.length} fresh tweets');

      if (freshPool.isNotEmpty) {
        await Repository.insertCachedMedia(freshPool);
      }

      final currentAsync = ref.read(feedNotifierProvider);
      if (currentAsync.hasValue) {
        final current = currentAsync.value!;
        
        final updatedLocalPool = await Repository.getUnplayedCachedMedia(
          settings.loadBatchSize * 3,
          filters: settings.filters,
        );
        
        var processed = DiscoveryEngine.interleave(freshPool, updatedLocalPool, settings.freshMixRatio);
        processed = DiscoveryEngine.applySaturation(processed, threshold: settings.saturationThreshold);

        state = AsyncData(current.copyWith(
          tweets: processed,
          cursorBottom: freshResponse.cursorBottom,
          isRefreshing: false,
        ));
        debugPrint('XFLOW: Feed state updated from background refresh. Total: ${processed.length}');
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
    if (currentState == null || currentState.isLoadingMore) {
      return;
    }

    final currentTweets = currentState.tweets;
    final currentCursor = currentState.cursorBottom;

    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // 1. Try to fetch from DB that aren't already in the current state
      final allUnplayed = await Repository.getUnplayedCachedMedia(
        settings.loadBatchSize * 2,
        filters: settings.filters,
      );
      final seenIds = currentTweets.map((t) => t.id).toSet();
      var newTweetsFromCache = allUnplayed.where((t) => !seenIds.contains(t.id)).toList();

      String? nextCursor = currentCursor;
      List<Tweet> finalNewTweets = [];

      // 2. If no new local tweets (or based on ratio), trigger an API fetch
      // For fetchMore, we can simplify: if we have cache, use it, else API.
      // Or we can also use the engine here.
      if (newTweetsFromCache.isEmpty) {
        final client = ref.read(twitterClientProvider);
        final response = await client.fetchSubscribedMedia(
          cursor: currentCursor,
          sort: settings.fetchStrategy,
          filters: settings.filters,
          subBatchSize: settings.syncBatchSize,
          loadBatchSize: settings.loadBatchSize,
          cooldownMinutes: settings.cooldownDuration,
        );
        
        finalNewTweets = response.tweets.where((t) => !seenIds.contains(t.id)).toList();
        nextCursor = response.cursorBottom;
        await Repository.insertCachedMedia(finalNewTweets);
      } else {
        finalNewTweets = newTweetsFromCache.take(settings.loadBatchSize).toList();
      }

      state = AsyncData(currentState.copyWith(
        tweets: [...currentTweets, ...finalNewTweets],
        cursorBottom: nextCursor,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('Error fetching more: $e');
      state = AsyncData(currentState.copyWith(isLoadingMore: false));
    }
  }
}

final feedNotifierProvider = AutoDisposeAsyncNotifierProvider<FeedNotifier, FeedState>(() => FeedNotifier());

// Legacy support for parts of the code that still expect feedProvider
final feedProvider = Provider.autoDispose<AsyncValue<List<Tweet>>>((ref) {
  final asyncState = ref.watch(feedNotifierProvider);
  return asyncState.whenData((state) => state.tweets);
});
