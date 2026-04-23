import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/entities.dart';
import '../../core/models/tweet.dart';
import '../feed/feed_provider.dart'; // For FeedState

final userProfileProvider = FutureProvider.family<Subscription?, String>((ref, screenName) async {
  final client = TwitterClient();
  return client.fetchProfile(screenName);
});

class UserMediaNotifier extends FamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String arg) async {
    final client = TwitterClient();
    final settings = ref.watch(settingsProvider);
    
    // 1. Load local items immediately for responsiveness
    final localTweets = await Repository.getUserCachedMedia(arg, settings.loadBatchSize);

    // 2. Trigger background refresh from API
    // We don't await this immediately so the local data shows up fast
    _refreshInBackground(arg, localTweets.map((t) => t.id).toSet());

    return FeedState(
      tweets: localTweets,
      cursorBottom: null, // Cursor will be updated by background refresh
    );
  }

  Future<void> _refreshInBackground(String screenName, Set<String> seenIds) async {
    final client = TwitterClient();
    final settings = ref.read(settingsProvider);

    try {
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cooldownMinutes: settings.cooldownDuration,
      );
      
      if (response.tweets.isNotEmpty) {
        await Repository.insertCachedMedia(response.tweets);
        
        // Check if we actually have new content to show
        final hasNew = response.tweets.any((t) => !seenIds.contains(t.id));
        
        if (hasNew) {
          // Re-fetch everything from DB to ensure correct order and deduplication
          final allTweets = await Repository.getUserCachedMedia(screenName, settings.loadBatchSize);
          state = AsyncData(FeedState(
            tweets: allTweets,
            cursorBottom: response.cursorBottom,
          ));
        } else if (state.value?.cursorBottom == null) {
          // Even if no new tweets, update the cursor so fetchMore works
          state = AsyncData(state.value!.copyWith(cursorBottom: response.cursorBottom));
        }
      }
    } catch (e) {
      debugPrint('Background user media refresh error: $e');
    }
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    final screenName = arg;
    if (currentState == null || currentState.isLoadingMore) {
      return;
    }

    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final client = TwitterClient();
      
      // Try fetching more from API
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cursor: currentState.cursorBottom,
        cooldownMinutes: settings.cooldownDuration,
      );
      
      final newTweets = response.tweets;
      if (newTweets.isNotEmpty) {
        await Repository.insertCachedMedia(newTweets);
      }
      
      // Deduplicate
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

// Legacy/Simple list provider
final userTweetsProvider = Provider.family<AsyncValue<List<Tweet>>, String>((ref, screenName) {
  final asyncState = ref.watch(userMediaNotifierProvider(screenName));
  return asyncState.whenData((state) => state.tweets);
});
