import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    Map<String, int> playedByUser,
  ) {
    var processed = DiscoveryEngine.interleave(freshPool, localPool, settings.freshMixRatio);
    processed = DiscoveryEngine.applySaturation(processed, threshold: settings.saturationThreshold);
    if (settings.unseenSubscriptionBoost) {
      processed = DiscoveryEngine.applyUnseenSubscriptionBoost(processed, playedByUser);
    }
    return processed;
  }

  @override
  FutureOr<FeedState> build() async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    final syncBatchSize = await _resolveSyncBatchSize(settings);
    
    debugPrint('XFLOW: Building FeedNotifier. fetchStrategy: ${settings.fetchStrategy}');

    try {
      // Stage 1: candidate retrieval (local + fresh)
      final localFuture = Repository.getCachedMediaCandidates(
        settings.loadBatchSize * 3,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );
      final freshFuture = client.fetchSubscribedMedia(
        sort: settings.fetchStrategy,
        filters: settings.filters,
        subBatchSize: syncBatchSize,
        loadBatchSize: settings.initialSyncCount,
        cooldownMinutes: settings.cooldownDuration,
        strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
        includeNativeRetweets: settings.includeNativeRetweets,
        useChunkedSubscriptions: settings.useChunkedSubscriptions,
      );

      final localPool = await localFuture;
      final freshResponse = await freshFuture;
      final freshPool = freshResponse.tweets;
      if (freshPool.isNotEmpty) {
        await Repository.insertCachedMedia(freshPool);
      }

      final playedByUser = settings.unseenSubscriptionBoost
          ? await Repository.getPlayedCountsByUser()
          : const <String, int>{};

      var tweets = _runDiscoveryPipeline(freshPool, localPool, settings, playedByUser);

      debugPrint('XFLOW: Local pool size after pipeline: ${tweets.length}');

      // If discovery produced nothing, make one fallback API call to avoid blank screen.
      if (tweets.isEmpty) {
        debugPrint('XFLOW: Discovery produced empty pool, performing fallback sync...');
        final response = await client.fetchSubscribedMedia(
          sort: settings.fetchStrategy,
          filters: settings.filters,
          subBatchSize: syncBatchSize,
          loadBatchSize: settings.initialSyncCount,
          cooldownMinutes: settings.cooldownDuration,
          strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
          includeNativeRetweets: settings.includeNativeRetweets,
          useChunkedSubscriptions: settings.useChunkedSubscriptions,
        );
        tweets = response.tweets;
        debugPrint('XFLOW: Fallback sync returned ${tweets.length} tweets');
        if (tweets.isNotEmpty) {
          await Repository.insertCachedMedia(tweets);
        }
      }

      final processed = tweets;

      // Trigger a follow-up refresh regardless to keep feed hot and up-to-date.
      Future.delayed(Duration.zero, () => _refreshInBackground());

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
    final syncBatchSize = await _resolveSyncBatchSize(settings);

    debugPrint('XFLOW: Background refresh started');

    try {
      final localPool = await Repository.getCachedMediaCandidates(
        settings.loadBatchSize * 3,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );

      final freshResponse = await client.fetchSubscribedMedia(
        sort: settings.fetchStrategy,
        filters: settings.filters,
        subBatchSize: syncBatchSize,
        loadBatchSize: settings.initialSyncCount,
        cooldownMinutes: settings.cooldownDuration,
        strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
        includeNativeRetweets: settings.includeNativeRetweets,
        useChunkedSubscriptions: settings.useChunkedSubscriptions,
      );

      final freshPool = freshResponse.tweets;
      debugPrint('XFLOW: Background refresh returned ${freshPool.length} fresh tweets');

      if (freshPool.isNotEmpty) {
        await Repository.insertCachedMedia(freshPool);
      }

      final currentAsync = ref.read(feedNotifierProvider);
      if (currentAsync.hasValue) {
        final current = currentAsync.value!;

        final playedByUser = settings.unseenSubscriptionBoost
            ? await Repository.getPlayedCountsByUser()
            : const <String, int>{};

        final processed = _runDiscoveryPipeline(freshPool, localPool, settings, playedByUser);

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
    final syncBatchSize = await _resolveSyncBatchSize(settings);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // 1. Try to fetch from DB that aren't already in the current state
      final allCandidates = await Repository.getCachedMediaCandidates(
        settings.loadBatchSize * 2,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );
      final seenIds = currentTweets.map((t) => t.id).toSet();
      var newTweetsFromCache = allCandidates.where((t) => !seenIds.contains(t.id)).toList();

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
          subBatchSize: syncBatchSize,
          loadBatchSize: settings.loadBatchSize,
          cooldownMinutes: settings.cooldownDuration,
          strictSubscriptionsOnly: settings.strictSubscriptionsOnly,
          includeNativeRetweets: settings.includeNativeRetweets,
          useChunkedSubscriptions: settings.useChunkedSubscriptions,
        );
        
        finalNewTweets = response.tweets.where((t) => !seenIds.contains(t.id)).toList();
        nextCursor = response.cursorBottom;
        await Repository.insertCachedMedia(finalNewTweets);
      } else {
        finalNewTweets = newTweetsFromCache.take(settings.loadBatchSize).toList();
      }
      
      finalNewTweets.shuffle(); // Diversify before appending
      var combined = [...currentTweets, ...finalNewTweets];
      combined = DiscoveryEngine.applySaturation(combined, threshold: settings.saturationThreshold);

      state = AsyncData(currentState.copyWith(
        tweets: combined,
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
