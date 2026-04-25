import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/navigation/navigation_provider.dart';
import '../../core/utils/media_cache_manager.dart';
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
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => ref.read(navigationProvider.notifier).back(),
                ),
                title: Text(profile.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref
                        .read(userMediaNotifierProvider(screenName).notifier)
                        .refresh(),
                  ),
                  IconButton(
                    icon: Icon(settings.isListView
                        ? Icons.grid_view
                        : Icons.view_list),
                    onPressed: () =>
                        settingsNotifier.toggleListView(!settings.isListView),
                  ),
                ],
                floating: true,
                pinned: true,
                snap: true,
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: profile.profileImageUrlHighRes !=
                                      null
                                  ? CachedNetworkImageProvider(
                                      profile.profileImageUrlHighRes!,
                                      cacheManager:
                                          CustomMediaCacheManager.getInstance(),
                                    )
                                  : null,
                              child: profile.profileImageUrlHighRes == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  '@${profile.screenName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (profile.description != null &&
                          profile.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            profile.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      Row(
                        children: [
                          _buildStat(
                              context,
                              '${_formatCount(profile.followingCount ?? 0)}',
                              'Following'),
                          const SizedBox(width: 24),
                          _buildStat(
                              context,
                              '${_formatCount(profile.followersCount ?? 0)}',
                              'Followers'),
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
                  final isRefreshing = state.isRefreshing;

                  if (tweets.isEmpty && !isRefreshing) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No media found'),
                        ),
                      ),
                    );
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 2,
                          child: isRefreshing
                              ? const LinearProgressIndicator(
                                  backgroundColor: Colors.transparent,
                                  minHeight: 2,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (tweets.isEmpty && isRefreshing)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(64.0),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Fetching latest items...',
                                      style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (settings.isListView)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == tweets.length - 1) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    ref
                                        .read(userMediaNotifierProvider(
                                                screenName)
                                            .notifier)
                                        .fetchMore();
                                  });
                                }
                                final tweet = tweets[index];
                                return Card(
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    key: ValueKey(tweet.id),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: tweet.mediaUrls.isNotEmpty
                                          ? SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: CachedNetworkImage(
                                                cacheManager:
                                                    CustomMediaCacheManager
                                                        .getInstance(),
                                                imageUrl: tweet.thumbnailUrl ??
                                                    tweet.mediaUrls.first,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 150,
                                                memCacheHeight: 150,
                                              ),
                                            )
                                          : const Icon(Icons.text_fields),
                                    ),
                                    title: Text(tweet.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      _formatDate(tweet.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                    ),
                                    onTap: () => ref
                                        .read(navigationProvider.notifier)
                                        .openUserMedia(screenName, index),
                                  ),
                                );
                              },
                              childCount: tweets.length,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == tweets.length - 1) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    ref
                                        .read(userMediaNotifierProvider(
                                                screenName)
                                            .notifier)
                                        .fetchMore();
                                  });
                                }

                                final tweet = tweets[index];
                                return GestureDetector(
                                  key: ValueKey(tweet.id),
                                  onTap: () {
                                    ref
                                        .read(navigationProvider.notifier)
                                        .openUserMedia(screenName, index);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (tweet.mediaUrls.isNotEmpty)
                                          CachedNetworkImage(
                                            cacheManager:
                                                CustomMediaCacheManager
                                                    .getInstance(),
                                            imageUrl: tweet.thumbnailUrl ??
                                                tweet.mediaUrls.first,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 300,
                                            memCacheHeight: 300,
                                            placeholder: (context, url) =>
                                                Container(
                                                    color: Colors.black12),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
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
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(fontSize: 10),
                                            ),
                                          ),
                                        if (tweet.isVideo)
                                          const Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Icon(
                                                Icons.play_circle_outline,
                                                color: Colors.white70,
                                                size: 20),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: tweets.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(64.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
