import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../../core/database/repository.dart';
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
    
    // 1. Try to get unplayed media from local DB
    List<Tweet> initialTweets = await Repository.getUnplayedCachedMedia(
      settings.loadBatchSize,
      filters: settings.filters,
    );

    String? cursorBottom;

    // 2. If DB is empty, fetch from API and save
    if (initialTweets.isEmpty) {
      final response = await client.fetchSubscribedMedia(
        sort: settings.sort,
        filters: settings.filters,
        subBatchSize: settings.syncBatchSize,
        loadBatchSize: settings.loadBatchSize,
        cooldownMinutes: settings.cooldownDuration,
      );
      initialTweets = response.tweets;
      cursorBottom = response.cursorBottom;
      await Repository.insertCachedMedia(initialTweets);
    }
    
    final pool = ref.read(playerPoolProvider.notifier);
    for (int i = 0; i < initialTweets.length && i < 3; i++) {
      final tweet = initialTweets[i];
      if (tweet.isVideo && tweet.mediaUrls.isNotEmpty) {
        pool.warmup(tweet.id, tweet.mediaUrls.first);
      }
    }
    
    return FeedState(
      tweets: initialTweets,
      cursorBottom: cursorBottom,
    );
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
      var newTweets = allUnplayed.where((t) => !seenIds.contains(t.id)).take(settings.loadBatchSize).toList();

      String? nextCursor = currentCursor;

      // 2. If no new local tweets, trigger an API fetch
      if (newTweets.isEmpty) {
        final client = ref.read(twitterClientProvider);
        final response = await client.fetchSubscribedMedia(
          cursor: currentCursor,
          sort: settings.sort,
          filters: settings.filters,
          subBatchSize: settings.syncBatchSize,
          loadBatchSize: settings.loadBatchSize,
          cooldownMinutes: settings.cooldownDuration,
        );
        
        newTweets = response.tweets.where((t) => !seenIds.contains(t.id)).toList();
        nextCursor = response.cursorBottom;
        await Repository.insertCachedMedia(newTweets);
      }

      state = AsyncData(currentState.copyWith(
        tweets: [...currentTweets, ...newTweets],
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
