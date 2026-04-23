import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/entities.dart';
import '../../core/database/repository.dart';
import '../../core/models/tweet.dart';
import '../feed/feed_provider.dart'; // For FeedState
import '../settings/settings_provider.dart';

final userProfileProvider = FutureProvider.family<Subscription?, String>((ref, screenName) async {
  final client = ref.watch(twitterClientProvider);
  return client.fetchProfile(screenName);
});

class UserMediaNotifier extends FamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String arg) async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    
    // Normalize handle: API and lookup prefer raw handle
    final screenName = arg.startsWith('@') ? arg.substring(1) : arg;

    debugPrint('XFLOW: Building UserMediaNotifier for $screenName');
    
    // 1. Load local items immediately for responsiveness
    final localTweets = await Repository.getUserCachedMedia(
      screenName, 
      settings.loadBatchSize,
      filters: settings.filters,
    );
    debugPrint('XFLOW: Found ${localTweets.length} local tweets for $screenName');

    // 2. Trigger background refresh from API
    _refreshInBackground(screenName, localTweets.map((t) => t.id).toSet());

    return FeedState(
      tweets: localTweets,
      cursorBottom: null,
      isRefreshing: true,
    );
  }

  Future<void> _refreshInBackground(String screenName, Set<String> seenIds) async {
    final client = ref.read(twitterClientProvider);
    final settings = ref.read(settingsProvider);

    try {
      debugPrint('XFLOW: Refreshing user media from API for $screenName');
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cooldownMinutes: settings.cooldownDuration,
      );
      
      debugPrint('XFLOW: API returned ${response.tweets.length} tweets for $screenName');

      if (response.tweets.isNotEmpty) {
        await Repository.insertCachedMedia(response.tweets);
        
        final hasNew = response.tweets.any((t) => !seenIds.contains(t.id));
        
        if (hasNew || (state.value?.tweets.isEmpty ?? true)) {
          final allTweets = await Repository.getUserCachedMedia(
            screenName, 
            settings.loadBatchSize,
            filters: settings.filters,
          );
          state = AsyncData(FeedState(
            tweets: allTweets,
            cursorBottom: response.cursorBottom,
            isRefreshing: false,
          ));
        } else {
          final current = state.value;
          if (current != null) {
            state = AsyncData(current.copyWith(
              cursorBottom: response.cursorBottom,
              isRefreshing: false,
            ));
          }
        }
      } else if (state.value != null) {
        state = AsyncData(state.value!.copyWith(
          cursorBottom: response.cursorBottom,
          isRefreshing: false,
        ));
      }
    } catch (e, st) {
      debugPrint('XFLOW: Background user media refresh error: $e\n$st');
      if (state.value != null) {
        state = AsyncData(state.value!.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    final rawArg = arg;
    final screenName = rawArg.startsWith('@') ? rawArg.substring(1) : rawArg;
    
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
      final uniqueNewTweets = newTweets.where((t) => !seenIds.contains(t.id)).toList();

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

final userMediaNotifierProvider = AsyncNotifierProviderFamily<UserMediaNotifier, FeedState, String>(() => UserMediaNotifier());

final userTweetsProvider = Provider.family<AsyncValue<List<Tweet>>, String>((ref, screenName) {
  final asyncState = ref.watch(userMediaNotifierProvider(screenName));
  return asyncState.whenData((state) => state.tweets);
});
