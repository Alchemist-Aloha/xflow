import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/entities.dart';
import '../../core/models/tweet.dart';
import '../feed/feed_provider.dart'; // For FeedState

import '../settings/settings_provider.dart';

final userProfileProvider = FutureProvider.family<Subscription?, String>((ref, screenName) async {
  final client = TwitterClient();
  return client.fetchProfile(screenName);
});

class UserMediaNotifier extends FamilyAsyncNotifier<FeedState, String> {
  @override
  FutureOr<FeedState> build(String arg) async {
    final client = TwitterClient();
    final settings = ref.watch(settingsProvider);
    final response = await client.fetchUserTweets(
      arg,
      sort: settings.sort,
      filter: settings.filter,
    );
    
    return FeedState(
      tweets: response.tweets,
      cursorBottom: response.cursorBottom,
    );
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    final screenName = arg;
    if (currentState == null || currentState.isLoadingMore || currentState.cursorBottom == null) {
      return;
    }

    final settings = ref.read(settingsProvider);
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final client = TwitterClient();
      final response = await client.fetchUserTweets(
        screenName,
        cursor: currentState.cursorBottom,
        sort: settings.sort,
        filter: settings.filter,
      );
      
      final newTweets = response.tweets;
      
      // Deduplicate
      final seenIds = currentState.tweets.map((t) => t.id).toSet();
      final uniqueNewTweets = newTweets.where((t) => !seenIds.contains(t.id)).toList();

      if (uniqueNewTweets.isNotEmpty || response.cursorBottom != currentState.cursorBottom) {
        state = AsyncData(currentState.copyWith(
          tweets: [...currentState.tweets, ...uniqueNewTweets],
          cursorBottom: response.cursorBottom,
          isLoadingMore: false,
        ));
      } else {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
      }
    } catch (e, st) {
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
