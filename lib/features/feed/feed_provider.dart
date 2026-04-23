import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_provider.dart';

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
    final response = await client.fetchSubscribedMedia();
    
    var tweets = response.tweets;
    tweets = _filterAndSort(tweets);

    return FeedState(
      tweets: tweets,
      cursorBottom: response.cursorBottom,
    );
  }

  List<Tweet> _filterAndSort(List<Tweet> tweets) {
    final settings = ref.read(settingsProvider);
    var result = tweets;
    if (settings.filter == MediaFilter.videoOnly) {
      result = result.where((t) => t.isVideo).toList();
    } else if (settings.filter == MediaFilter.imageOnly) {
      result = result.where((t) => !t.isVideo).toList();
    }
    if (settings.sort == FeedSort.oldest) {
      result = result.reversed.toList();
    }
    return result;
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoadingMore || currentState.cursorBottom == null) {
      debugPrint('FeedNotifier: fetchMore skipped. isLoadingMore: ${currentState?.isLoadingMore}, cursorBottom: ${currentState?.cursorBottom}');
      return;
    }

    debugPrint('FeedNotifier: Fetching more tweets with cursor: ${currentState.cursorBottom}');
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final client = ref.read(twitterClientProvider);
      final response = await client.fetchSubscribedMedia(cursor: currentState.cursorBottom);
      
      var newTweets = _filterAndSort(response.tweets);
      debugPrint('FeedNotifier: Received ${response.tweets.length} raw tweets, ${newTweets.length} after filtering');
      
      // Deduplicate
      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      newTweets = newTweets.where((t) => !seenIds.contains(t.id)).toList();
      debugPrint('FeedNotifier: ${newTweets.length} new unique tweets after deduplication');

      if (newTweets.isNotEmpty || response.cursorBottom != currentState.cursorBottom) {
        state = AsyncData(currentState.copyWith(
          tweets: [...currentState.tweets, ...newTweets],
          cursorBottom: response.cursorBottom,
          isLoadingMore: false,
        ));
        debugPrint('FeedNotifier: state updated. Total tweets: ${state.value?.tweets.length}, next cursor: ${response.cursorBottom}');
      } else {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        debugPrint('FeedNotifier: no new data found.');
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
