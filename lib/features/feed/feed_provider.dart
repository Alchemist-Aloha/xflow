import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';

final twitterClientProvider = Provider((ref) => TwitterClient());

final feedProvider = FutureProvider<List<Tweet>>((ref) async {
  final client = ref.watch(twitterClientProvider);
  return client.fetchTrendingMedia();
});
