import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
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
    
    final response = await client.fetchSubscribedMedia(
      sort: settings.sort,
      filters: settings.filters,
    );
    
    final pool = ref.read(playerPoolProvider.notifier);
    for (int i = 0; i < response.tweets.length && i < 3; i++) {
      final tweet = response.tweets[i];
      if (tweet.isVideo && tweet.mediaUrls.isNotEmpty) {
        pool.warmup(tweet.id, tweet.mediaUrls.first);
      }
    }
    
    return FeedState(
      tweets: response.tweets,
      cursorBottom: response.cursorBottom,
    );
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoadingMore || currentState.cursorBottom == null) {
      return;
    }

    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final client = ref.read(twitterClientProvider);
      final response = await client.fetchSubscribedMedia(
        cursor: currentState.cursorBottom,
        sort: settings.sort,
        filters: settings.filters,
      );
      
      var newTweets = response.tweets;
      
      // Deduplicate
      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      newTweets = newTweets.where((t) => !seenIds.contains(t.id)).toList();

      if (newTweets.isNotEmpty || response.cursorBottom != currentState.cursorBottom) {
        state = AsyncData(currentState.copyWith(
          tweets: [...currentState.tweets, ...newTweets],
          cursorBottom: response.cursorBottom,
          isLoadingMore: false,
        ));
      } else {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
      }
    } catch (e, st) {
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
