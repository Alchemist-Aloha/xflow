import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/database/entities.dart';
import '../../core/models/tweet.dart';
import 'profile_provider.dart';
import 'user_media_feed_screen.dart';

class UserDetailsScreen extends ConsumerWidget {
  final String screenName;

  const UserDetailsScreen({super.key, required this.screenName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(screenName));
    final tweetsAsync = ref.watch(userMediaNotifierProvider(screenName));

    return Scaffold(
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text('@${profile.screenName}'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: profile.profileImageUrl != null
                                ? CachedNetworkImageProvider(profile.profileImageUrl!)
                                : null,
                            child: profile.profileImageUrl == null
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@${profile.screenName}',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (profile.description != null && profile.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            profile.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      Row(
                        children: [
                          _buildStat(context, '${profile.followingCount ?? 0}', 'Following'),
                          const SizedBox(width: 24),
                          _buildStat(context, '${profile.followersCount ?? 0}', 'Followers'),
                        ],
                      ),
                      const Divider(height: 32),
                    ],
                  ),
                ),
              ),
              tweetsAsync.when(
                data: (state) {
                  final tweets = state.tweets;
                  if (tweets.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Text('No media found')),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Check if we need to load more when reaching the end of the grid
                          if (index == tweets.length - 1) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(userMediaNotifierProvider(screenName).notifier).fetchMore();
                            });
                          }

                          final tweet = tweets[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserMediaFeedScreen(
                                    screenName: screenName,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: tweet.mediaUrls.first,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.black12),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                                if (tweet.isVideo)
                                  const Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
                                  ),
                              ],
                            ),
                          );
                        },
                        childCount: tweets.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading profile: $e')),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
