import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/tweet.dart';
import '../../core/client/twitter_client.dart';
import '../../core/navigation/navigation_provider.dart';
import '../subscriptions/subscription_list_screen.dart';
import 'feed_provider.dart';

final tweetDetailProvider =
    FutureProvider.family<TweetResponse, String>((ref, tweetId) async {
  final client = ref.read(twitterClientProvider);
  return client.fetchTweetDetail(tweetId);
});

class TweetRepliesSheet extends ConsumerWidget {
  final Tweet tweet;

  const TweetRepliesSheet({super.key, required this.tweet});

  static void show(BuildContext context, Tweet tweet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TweetRepliesSheet(tweet: tweet),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(tweetDetailProvider(tweet.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Replies',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: repliesAsync.when(
                  data: (response) {
                    final replies =
                        response.tweets.where((t) => t.id != tweet.id).toList();
                    if (replies.isEmpty) {
                      return ListView(
                        controller: scrollController,
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Center(
                              child: Text('No replies yet'),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        return _ReplyTile(tweet: replies[index]);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, st) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error loading replies: $e'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: tweet.userAvatarUrlHighRes != null
                  ? CachedNetworkImageProvider(tweet.userAvatarUrlHighRes!)
                  : null,
              child: tweet.userAvatarUrlHighRes == null
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    tweet.userHandle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ref
                    .watch(subscriptionListProvider)
                    .isSubscribed(tweet.userHandle)) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle,
                      color: Colors.blueAccent, size: 14),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  tweet.text,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _formatCount(tweet.favoriteCount),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              // Deep dive into a reply's own thread?
              // For now, let's keep it simple or allow navigation to user
              final handle = tweet.userHandle.replaceFirst('@', '');
              ref.read(navigationProvider.notifier).selectUser(handle);
              Navigator.pop(context); // Close sheet when navigating away
            },
          ),
        ),
        const Divider(indent: 72, height: 1),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
