import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/navigation_provider.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/repository.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_provider.dart';
import 'feed_provider.dart';

final hashtagFeedNotifierProvider = AutoDisposeAsyncNotifierProviderFamily<
    HashtagFeedNotifier, FeedState, String>(
  () => HashtagFeedNotifier(),
);

class HashtagFeedNotifier
    extends AutoDisposeFamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String hashtag) async {
    final settings = ref.watch(settingsProvider);

    // 1. Try to load from cache immediately if it's a hashtag
    final cached =
        await Repository.getHashtagCachedMedia(hashtag, settings.loadBatchSize);

    // Trigger async fetch in the background
    _fetchFreshData(hashtag);

    return FeedState(
      tweets: cached.map((t) => t.copyWith(source: 'Cache')).toList(),
      isRefreshing: true,
    );
  }

  Future<void> _fetchFreshData(String hashtag) async {
    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    try {
      final response = await client.fetchTrendingMedia(
        query: hashtag,
        count: settings.timelineBatchSize,
        sort: FeedSort.trending,
      );

      if (response.tweets.isNotEmpty) {
        await Repository.insertCachedMedia(response.tweets);

        final freshTweets =
            response.tweets.map((t) => t.copyWith(source: 'API')).toList();

        final currentState = state.value;
        if (currentState != null) {
          state = AsyncData(FeedState(
            tweets: freshTweets,
            cursorBottom: response.cursorBottom,
            isRefreshing: false,
          ));
        }
      } else {
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncData(currentState.copyWith(isRefreshing: false));
        }
      }
    } catch (e) {
      debugPrint('XFLOW: Background hashtag fetch error: $e');
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(currentState.copyWith(isRefreshing: true));
    await _fetchFreshData(arg);
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        currentState.cursorBottom == null) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));
    final hashtag = arg;
    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    try {
      final response = await client.fetchTrendingMedia(
        query: hashtag,
        cursor: currentState.cursorBottom,
        count: settings.loadBatchSize,
        sort: FeedSort.trending,
      );

      if (response.tweets.isEmpty) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final newTweets = response.tweets;
      await Repository.insertCachedMedia(newTweets);

      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      final uniqueNew =
          newTweets.where((t) => !seenIds.contains(t.id)).toList();

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

class HashtagFeedScreen extends ConsumerWidget {
  final String hashtag;
  final bool showBackButton;

  const HashtagFeedScreen(
      {super.key, required this.hashtag, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(hashtagFeedNotifierProvider(hashtag));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => ref.read(navigationProvider.notifier).back(),
              )
            : IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref
                    .read(hashtagFeedNotifierProvider(hashtag).notifier)
                    .refresh(),
              ),
        title: Text(hashtag, style: const TextStyle(color: Colors.white)),
        actions: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => ref
                  .read(hashtagFeedNotifierProvider(hashtag).notifier)
                  .refresh(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(hashtagFeedNotifierProvider(hashtag).notifier).refresh(),
        child: feedAsync.when(
          data: (state) {
            final tweets = state.tweets;
            if (tweets.isEmpty && !state.isRefreshing) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No results found',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => ref
                                .read(hashtagFeedNotifierProvider(hashtag)
                                    .notifier)
                                .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                if (state.isRefreshing)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tweets.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tweets.length) {
                        if (!state.isLoadingMore) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref
                                .read(hashtagFeedNotifierProvider(hashtag)
                                    .notifier)
                                .fetchMore();
                          });
                        }
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator()));
                      }

                      final tweet = tweets[index];
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: tweet.mediaUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    tweet.thumbnailUrl ?? tweet.mediaUrls.first,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                        Icons.broken_image,
                                        size: 50),
                                  ),
                                )
                              : const Icon(Icons.text_snippet,
                                  color: Colors.white24, size: 50),
                          title: Text(tweet.userHandle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          subtitle: Text(tweet.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            ref
                                .read(navigationProvider.notifier)
                                .selectTweet(tweet);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $e', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .read(hashtagFeedNotifierProvider(hashtag).notifier)
                      .refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
