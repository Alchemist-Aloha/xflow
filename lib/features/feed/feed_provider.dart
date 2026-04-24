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
  }) {
    final seenIds = <String>{};
    final seenMediaUrls = <String>{};

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

    final uniqueFresh = deduplicate(freshPool);
    final uniqueLocal = deduplicate(localPool);

    var processed = DiscoveryEngine.interleave(
        uniqueFresh, uniqueLocal, settings.freshMixRatio);

    processed = DiscoveryEngine.applySaturation(
      processed,
      threshold: settings.saturationThreshold,
      windowSize: settings.saturationWindow,
      startIndex: protectedIndex,
    );

    if (settings.unseenSubscriptionBoost) {
      processed = DiscoveryEngine.applyUnseenSubscriptionBoost(
        processed,
        playedByUser,
        lookahead: settings.unseenBoostLookahead,
        startIndex: protectedIndex,
      );
    }
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
        settings.loadBatchSize * 3,
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
      Future.delayed(Duration.zero, () => _refreshInBackground());

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

  Future<void> _refreshInBackground() async {
    if (!ref.exists(feedNotifierProvider)) return;

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);
    final syncBatchSize = await _resolveSyncBatchSize(settings);

    debugPrint('XFLOW: Background refresh started');

    try {
      // 1. Fetch from API
      final freshResponse = await client.fetchSubscribedMedia(
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
        settings.loadBatchSize * 5,
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
          protectedIndex: 2,
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

  Future<void> fetchMore({int retryCount = 0}) async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoadingMore || retryCount > 3) {
      return;
    }

    final currentTweets = currentState.tweets;
    final currentCursor = currentState.cursorBottom;
    final settings = ref.read(settingsProvider);
    final syncBatchSize = await _resolveSyncBatchSize(settings);
    
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // 1. Try to fetch from DB first
      final allCandidates = await Repository.getCachedMediaCandidates(
        settings.loadBatchSize * 3,
        avoidWatchedContent: settings.avoidWatchedContent,
        filters: settings.filters,
      );
      
      final seenIds = currentTweets.map((t) => t.id).toSet();
      final seenMedia = currentTweets.where((t) => t.mediaUrls.isNotEmpty).map((t) => t.mediaUrls.first).toSet();
      
      var newTweets = allCandidates.where((t) {
        final isNewId = !seenIds.contains(t.id);
        final isNewMedia = t.mediaUrls.isEmpty || !seenMedia.contains(t.mediaUrls.first);
        return isNewId && isNewMedia;
      }).toList();

      String? nextCursor = currentCursor;

      // 2. If local pool is dry or small, hit the API
      if (newTweets.length < 5) {
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
          minFaves: settings.minFavesFilter,
        );

        final freshUnique = response.tweets.where((t) {
          final isNewId = !seenIds.contains(t.id);
          final isNewMedia = t.mediaUrls.isEmpty || !seenMedia.contains(t.mediaUrls.first);
          return isNewId && isNewMedia;
        }).toList();

        await Repository.insertCachedMedia(response.tweets);
        newTweets.addAll(freshUnique);
        nextCursor = response.cursorBottom;
      }

      if (newTweets.isEmpty && nextCursor != null) {
        // Deduplication ate everything, try one more time with the new cursor
        state = AsyncData(currentState.copyWith(isLoadingMore: false, cursorBottom: nextCursor));
        return fetchMore(retryCount: retryCount + 1);
      }

      final finalNewTweets = newTweets
          .take(settings.loadBatchSize)
          .map((t) => t.copyWith(source: newTweets.first.source ?? 'Mixed'))
          .toList();

      finalNewTweets.shuffle();
      var combined = [...currentTweets, ...finalNewTweets];
      
      // Apply diversity enforcement to the new tail
      combined = DiscoveryEngine.applySaturation(
        combined,
        threshold: settings.saturationThreshold,
        startIndex: currentTweets.length,
      );

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

final feedNotifierProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, FeedState>(
        () => FeedNotifier());

// Legacy support for parts of the code that still expect feedProvider
final feedProvider = Provider.autoDispose<AsyncValue<List<Tweet>>>((ref) {
  final asyncState = ref.watch(feedNotifierProvider);
  return asyncState.whenData((state) => state.tweets);
});
