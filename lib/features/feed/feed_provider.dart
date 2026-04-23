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

  FeedState({required this.tweets, this.cursorBottom, this.isLoadingMore = false});

  FeedState copyWith({List<Tweet>? tweets, String? cursorBottom, bool? isLoadingMore}) {
    return FeedState(
      tweets: tweets ?? this.tweets,
      cursorBottom: cursorBottom ?? this.cursorBottom,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class FeedNotifier extends AutoDisposeAsyncNotifier<FeedState> {
  @override
  FutureOr<FeedState> build() async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    
    // 1. Try to get unplayed media from local DB
    List<Tweet> initialTweets = await Repository.getUnplayedCachedMedia(20);

    String? cursorBottom;

    // 2. If DB is empty, fetch from API and save
    if (initialTweets.isEmpty) {
      final response = await client.fetchSubscribedMedia(
        sort: settings.sort,
        filters: settings.filters,
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

    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // 1. Try to fetch from DB that aren't already in the current state
      final allUnplayed = await Repository.getUnplayedCachedMedia(100);
      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      var newTweets = allUnplayed.where((t) => !seenIds.contains(t.id)).take(20).toList();

      String? nextCursor = currentState.cursorBottom;

      // 2. If no new local tweets, trigger an API fetch
      if (newTweets.isEmpty) {
        final client = ref.read(twitterClientProvider);
        final response = await client.fetchSubscribedMedia(
          cursor: currentState.cursorBottom,
          sort: settings.sort,
          filters: settings.filters,
        );
        
        newTweets = response.tweets.where((t) => !seenIds.contains(t.id)).toList();
        nextCursor = response.cursorBottom;
        await Repository.insertCachedMedia(newTweets);
      }

      state = AsyncData(currentState.copyWith(
        tweets: [...currentState.tweets, ...newTweets],
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
