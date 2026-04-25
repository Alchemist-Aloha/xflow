import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/navigation_provider.dart';
import '../../core/client/twitter_client.dart';
import 'feed_provider.dart';

final hashtagFeedNotifierProvider = AutoDisposeAsyncNotifierProviderFamily<
    HashtagFeedNotifier, FeedState, String>(
  () => HashtagFeedNotifier(),
);

class HashtagFeedNotifier
    extends AutoDisposeFamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String hashtag) async {
    final client = ref.read(twitterClientProvider);
    final response = await client.fetchTrendingMedia(query: hashtag, count: 20);
    return FeedState(
        tweets: response.tweets, cursorBottom: response.cursorBottom);
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        currentState.cursorBottom == null) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));
    final hashtag = arg;
    final client = ref.read(twitterClientProvider);

    try {
      final response = await client.fetchTrendingMedia(
        query: hashtag,
        cursor: currentState.cursorBottom,
        count: 20,
      );

      if (response.tweets.isEmpty) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      state = AsyncData(currentState.copyWith(
        tweets: [...currentState.tweets, ...response.tweets],
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

  const HashtagFeedScreen({super.key, required this.hashtag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(hashtagFeedNotifierProvider(hashtag));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(navigationProvider.notifier).back(),
        ),
        title: Text(hashtag),
      ),
      body: feedAsync.when(
        data: (state) {
          final tweets = state.tweets;
          if (tweets.isEmpty) {
            return const Center(child: Text('No results found'));
          }

          return ListView.builder(
            itemCount: tweets.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == tweets.length) {
                if (!state.isLoadingMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(hashtagFeedNotifierProvider(hashtag).notifier)
                        .fetchMore();
                  });
                }
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator()));
              }

              final tweet = tweets[index];
              return ListTile(
                title: Text(tweet.userHandle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(tweet.text),
                onTap: () {
                  ref.read(navigationProvider.notifier).selectTweet(tweet);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
