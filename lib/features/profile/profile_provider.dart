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

    debugPrint('XFLOW: Building UserMediaNotifier for $screenName (Online Only)');
    
    // We start with an empty state and mark it as refreshing immediately
    // In build(), returning a Future will make the UI show the loading state.
    // However, the user wants it to actually FETCH now.
    
    try {
      final response = await client.fetchUserTimelineByScreenName(
        screenName,
        cooldownMinutes: settings.cooldownDuration,
      );

      debugPrint('XFLOW: Initial online fetch for $screenName returned ${response.tweets.length} tweets');

      if (response.tweets.isNotEmpty) {
        // Save to cache for other screens, but we return the fresh results directly
        await Repository.insertCachedMedia(response.tweets);
      }

      return FeedState(
        tweets: response.tweets,
        cursorBottom: response.cursorBottom,
        isRefreshing: false,
      );
    } catch (e, st) {
      debugPrint('XFLOW: User media fetch error for $screenName: $e\n$st');
      // Fallback to cache ONLY on error if available, or empty
      final cached = await Repository.getUserCachedMedia(screenName, settings.loadBatchSize);
      return FeedState(
        tweets: cached,
        isRefreshing: false,
      );
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
