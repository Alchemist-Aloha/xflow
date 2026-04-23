import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/navigation/navigation_provider.dart';
import '../settings/settings_provider.dart';
import 'profile_provider.dart';

class UserDetailsScreen extends ConsumerWidget {
  final String screenName;

  const UserDetailsScreen({super.key, required this.screenName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(screenName));
    final tweetsAsync = ref.watch(userMediaNotifierProvider(screenName));
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => ref.read(navigationProvider.notifier).back(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(settings.isListView ? Icons.grid_view : Icons.view_list),
                    onPressed: () => settingsNotifier.toggleListView(!settings.isListView),
                  ),
                ],
                floating: true,
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
                      child: Center(child: Text('No tweets found')),
                    );
                  }

                  if (settings.isListView) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == tweets.length - 1) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(userMediaNotifierProvider(screenName).notifier).fetchMore();
                            });
                          }
                          final tweet = tweets[index];
                          return ListTile(
                            leading: tweet.mediaUrls.isNotEmpty 
                              ? SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CachedNetworkImage(
                                    imageUrl: tweet.thumbnailUrl ?? tweet.mediaUrls.first,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.text_fields),
                            title: Text(tweet.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(tweet.createdAt?.toString().split('.').first ?? ''),
                            onTap: () => ref.read(navigationProvider.notifier).openUserMedia(screenName, index),
                          );
                        },
                        childCount: tweets.length,
                      ),
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
                              ref.read(navigationProvider.notifier).openUserMedia(screenName, index);
                            },
                            child: Container(
                              color: Colors.black12,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (tweet.mediaUrls.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: tweet.thumbnailUrl ?? tweet.mediaUrls.first,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 300,
                                      memCacheHeight: 300,
                                      placeholder: (context, url) => Container(color: Colors.black12),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      alignment: Alignment.center,
                                      child: Text(
                                        tweet.text,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                                      ),
                                    ),
                                  if (tweet.isVideo)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
                                    ),
                                ],
                              ),
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
