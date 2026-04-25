import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/repository.dart';
import '../../core/models/tweet.dart';
import 'feed_provider.dart';
import '../settings/settings_provider.dart';

class HashtagListNotifier extends AsyncNotifier<List<String>> {
  @override
  FutureOr<List<String>> build() async {
    return Repository.getHashtags();
  }

  Future<void> addHashtag(String tag) async {
    final cleanTag = tag.startsWith('#') ? tag : '#$tag';
    await Repository.addHashtag(cleanTag);
    ref.invalidateSelf();
  }

  Future<void> removeHashtag(String tag) async {
    await Repository.deleteHashtag(tag);
    ref.invalidateSelf();
  }
}

final hashtagListProvider =
    AsyncNotifierProvider<HashtagListNotifier, List<String>>(
  () => HashtagListNotifier(),
);

class HashtagMediaNotifier extends FamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String hashtag) async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);

    // For now, hashtag feed is purely online as requested ("just pull api data and display")
    // but we still want a FeedState structure.

    final response = await client.fetchTrendingMedia(
      query: hashtag,
      count: settings.timelineBatchSize,
      sort: FeedSort.trending,
    );

    return FeedState(
      tweets: response.tweets,
      cursorBottom: response.cursorBottom,
      isRefreshing: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        currentState.cursorBottom == null) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    try {
      final response = await client.fetchTrendingMedia(
        query: arg,
        cursor: currentState.cursorBottom,
        count: settings.loadBatchSize,
        sort: FeedSort.trending,
      );

      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      final uniqueNew =
          response.tweets.where((t) => !seenIds.contains(t.id)).toList();

      state = AsyncData(currentState.copyWith(
        tweets: [...currentState.tweets, ...uniqueNew],
        cursorBottom: response.cursorBottom,
        isLoadingMore: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoadingMore: false));
    }
  }
}

final hashtagMediaProvider =
    AsyncNotifierProviderFamily<HashtagMediaNotifier, FeedState, String>(
  () => HashtagMediaNotifier(),
);
