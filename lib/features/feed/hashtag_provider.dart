import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/repository.dart';
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

String _normalizeHashtag(String hashtag) {
  final trimmed = hashtag.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.startsWith('#') ? trimmed : '#$trimmed';
}

String _mediaSearchQuery(String hashtag) {
  final normalized = _normalizeHashtag(hashtag);
  return '$normalized (filter:images OR filter:videos)';
}

String _plainSearchQuery(String hashtag) {
  return _normalizeHashtag(hashtag);
}

class HashtagMediaNotifier extends AsyncNotifier<FeedState> {
  HashtagMediaNotifier(this.arg);
  final String arg;
  String? _activeQuery;

  @override
  FutureOr<FeedState> build() async {
    final hashtag = arg;
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    final mediaQuery = _mediaSearchQuery(hashtag);
    final plainQuery = _plainSearchQuery(hashtag);

    var response = await client.fetchTrendingMedia(
      query: mediaQuery,
      count: settings.timelineBatchSize,
      sort: FeedSort.trending,
    );
    _activeQuery = mediaQuery;

    if (response.tweets.isEmpty) {
      response = await client.fetchTrendingMedia(
        query: mediaQuery,
        count: settings.timelineBatchSize,
        sort: FeedSort.latest,
      );
    }

    if (response.tweets.isEmpty) {
      response = await client.fetchTrendingMedia(
        query: plainQuery,
        count: settings.timelineBatchSize,
        sort: FeedSort.latest,
      );
      _activeQuery = plainQuery;
    }

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
        currentState.cursorBottom == null) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);
    final query = _activeQuery ?? _mediaSearchQuery(arg);

    try {
      final response = await client.fetchTrendingMedia(
        query: query,
        cursor: currentState.cursorBottom,
        count: settings.loadBatchSize,
        sort: FeedSort.latest,
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
    AsyncNotifierProvider.family<HashtagMediaNotifier, FeedState, String>(
  HashtagMediaNotifier.new,
);
