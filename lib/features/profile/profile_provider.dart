import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/entities.dart';
import '../../core/database/repository.dart';
import '../../core/models/tweet.dart';
import '../feed/feed_provider.dart'; // For FeedState
import '../settings/settings_provider.dart';

final userProfileProvider =
    FutureProvider.family<Subscription?, String>((ref, screenName) async {
  final client = ref.watch(twitterClientProvider);
  return client.fetchProfile(screenName);
});

class UserMediaNotifier extends FamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String arg) async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    final screenName = arg.startsWith('@') ? arg.substring(1) : arg;

    // 1. Try to load from cache immediately to show SOMETHING
    final cached = await Repository.getUserCachedMedia(
        screenName, settings.loadBatchSize);
    
    // Trigger async fetch in the background
    _fetchFreshData(screenName);

    return FeedState(
      tweets: cached.map((t) => t.copyWith(source: 'Cache')).toList(),
      isRefreshing: true, // Mark as refreshing while we fetch
    );
  }

  Future<void> _fetchFreshData(String screenName) async {
    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    try {
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cooldownMinutes: settings.cooldownDuration,
      );

      if (response.tweets.isNotEmpty) {
        await Repository.insertCachedMedia(response.tweets);
        
        final freshTweets = response.tweets.map((t) => t.copyWith(source: 'API')).toList();
        
        // Update state with fresh data
        final currentState = state.value;
        if (currentState != null) {
          // Merge or replace? For profile, we usually want fresh first
          state = AsyncData(FeedState(
            tweets: freshTweets,
            cursorBottom: response.cursorBottom,
            isRefreshing: false,
          ));
        }
      } else {
        // No new tweets, just clear refreshing flag
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncData(currentState.copyWith(isRefreshing: false));
        }
      }
    } catch (e) {
      debugPrint('XFLOW: Background user media fetch error: $e');
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    final screenName = arg.startsWith('@') ? arg.substring(1) : arg;

    if (currentState == null || currentState.isLoadingMore) {
      return;
    }

    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cursor: currentState.cursorBottom,
        cooldownMinutes: settings.cooldownDuration,
      );

      final newTweets = response.tweets;
      if (newTweets.isNotEmpty) {
        await Repository.insertCachedMedia(newTweets);
      }

      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      final uniqueNewTweets =
          newTweets.where((t) => !seenIds.contains(t.id)).toList();

      state = AsyncData(currentState.copyWith(
        tweets: [...currentState.tweets, ...uniqueNewTweets],
        cursorBottom: response.cursorBottom,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('Error fetching more user media: $e');
      state = AsyncData(currentState.copyWith(isLoadingMore: false));
    }
  }
}

final userMediaNotifierProvider =
    AsyncNotifierProviderFamily<UserMediaNotifier, FeedState, String>(
        () => UserMediaNotifier());

final userTweetsProvider =
    Provider.family<AsyncValue<List<Tweet>>, String>((ref, screenName) {
  final asyncState = ref.watch(userMediaNotifierProvider(screenName));
  return asyncState.whenData((state) => state.tweets);
});
