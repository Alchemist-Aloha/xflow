import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_provider.dart';

final twitterClientProvider = Provider((ref) => TwitterClient());

final feedProvider = FutureProvider<List<Tweet>>((ref) async {
  final client = ref.watch(twitterClientProvider);
  final settings = ref.watch(settingsProvider);
  
  var tweets = await client.fetchTrendingMedia();

  // Apply Filter
  if (settings.filter == MediaFilter.videoOnly) {
    tweets = tweets.where((t) => t.isVideo).toList();
  } else if (settings.filter == MediaFilter.imageOnly) {
    tweets = tweets.where((t) => !t.isVideo).toList();
  }

  // Apply Sort (Mock sorting for now)
  if (settings.sort == FeedSort.oldest) {
    tweets = tweets.reversed.toList();
  }

  return tweets;
});
