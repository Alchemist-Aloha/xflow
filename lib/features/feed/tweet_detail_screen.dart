import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/tweet.dart';
import '../../core/navigation/navigation_provider.dart';
import '../../core/client/twitter_client.dart';
import '../profile/user_details_screen.dart';
import 'feed_provider.dart';

final tweetDetailProvider =
    FutureProvider.family<TweetResponse, String>((ref, tweetId) async {
  final client = ref.read(twitterClientProvider);
  return client.fetchTweetDetail(tweetId);
});

class TweetDetailScreen extends ConsumerWidget {
  final Tweet tweet;

  const TweetDetailScreen({super.key, required this.tweet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(tweetDetailProvider(tweet.id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(navigationProvider.notifier).back(),
        ),
        title: const Text('Tweet'),
      ),
      body: CustomScrollView(
        slivers: [
          // Main Tweet
          SliverToBoxAdapter(
            child: _MainTweet(tweet: tweet),
          ),
          const SliverToBoxAdapter(child: Divider()),
          // Replies
          repliesAsync.when(
            data: (response) {
              final replies =
                  response.tweets.where((t) => t.id != tweet.id).toList();
              if (replies.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No replies yet'),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final reply = replies[index];
                    return _ReplyTile(tweet: reply);
                  },
                  childCount: replies.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Center(child: Text('Error loading replies: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainTweet extends ConsumerWidget {
  final Tweet tweet;
  const _MainTweet({required this.tweet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: tweet.userAvatarUrlHighRes != null
                    ? CachedNetworkImageProvider(tweet.userAvatarUrlHighRes!)
                    : null,
                child: tweet.userAvatarUrlHighRes == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tweet.userHandle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tweet.text, style: const TextStyle(fontSize: 18, height: 1.4)),
          if (tweet.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: tweet.thumbnailUrl ?? tweet.mediaUrls.first,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                  icon: Icons.favorite_border,
                  label: tweet.favoriteCount.toString()),
              const SizedBox(width: 20),
              _Stat(
                  icon: Icons.chat_bubble_outline,
                  label: tweet.replyCount.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends ConsumerWidget {
  final Tweet tweet;
  const _ReplyTile({required this.tweet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundImage: tweet.userAvatarUrlHighRes != null
                ? CachedNetworkImageProvider(tweet.userAvatarUrlHighRes!)
                : null,
            child: tweet.userAvatarUrlHighRes == null
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          title: Text(tweet.userHandle,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(tweet.text),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite_border,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(tweet.favoriteCount.toString(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          onTap: () {
            ref.read(navigationProvider.notifier).selectTweet(tweet);
          },
        ),
        const Divider(indent: 72, height: 1),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
