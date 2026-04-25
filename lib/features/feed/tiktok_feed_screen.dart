import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../player/player_pool_provider.dart';
import 'feed_provider.dart';
import '../player/widgets/media_container.dart';
import '../../core/models/tweet.dart';
import '../../core/database/repository.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_provider.dart';
import '../auth/login_screen.dart';
import '../../core/client/account_provider.dart';
import '../../core/navigation/navigation_provider.dart';
import 'widgets/tweet_text_overlay.dart';

class TiktokFeedScreen extends ConsumerStatefulWidget {
  const TiktokFeedScreen({super.key});

  @override
  ConsumerState<TiktokFeedScreen> createState() => _TiktokFeedScreenState();
}

class _TiktokFeedScreenState extends ConsumerState<TiktokFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentIndex) {
      setState(() {
        _currentIndex = page;
      });
      _managePool();

      final feedAsync = ref.read(feedNotifierProvider);
      if (feedAsync.hasValue) {
        final tweets = feedAsync.value!.tweets;

        if (page < tweets.length) {
          Repository.markMediaAsPlayed(tweets[page].id);
        }

        final settings = ref.read(settingsProvider);
        if (page >= tweets.length - settings.lazyLoadThreshold &&
            !feedAsync.value!.isRefreshing) {
          ref.read(feedNotifierProvider.notifier).fetchMore();
        }
      }
    }
  }

  void _managePool() {
    try {
      final feedAsync = ref.read(feedNotifierProvider);
      final state = feedAsync.value;
      if (state == null) return;
      final tweets = state.tweets;

      final pool = ref.read(playerPoolProvider.notifier);
      final activeIds = <String>{};

      for (int i = _currentIndex - 1; i <= _currentIndex + 3; i++) {
        if (i >= 0 && i < tweets.length) {
          final tweet = tweets[i];
          activeIds.add(tweet.id);

          if (tweet.isVideo && tweet.mediaUrls.isNotEmpty) {
            pool.warmup(tweet.id, tweet.mediaUrls.first);
          } else if (tweet.mediaUrls.isNotEmpty) {
            for (final url in tweet.mediaUrls) {
              precacheImage(NetworkImage(url), context);
            }
          }
        }
      }
      pool.cleanupExcept(activeIds);
    } catch (e) {
      debugPrint('XFLOW: Error in _managePool: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _pageController.jumpToPage(0);
            ref.read(feedNotifierProvider.notifier).refresh();
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/app_icon.svg',
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              "XFlow",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (account == null)
            TextButton.icon(
              onPressed: () => _goToLogin(),
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _buildMediaFeed(),
    );
  }

  Widget _buildMediaFeed() {
    final feedAsync = ref.watch(feedNotifierProvider);
    final nav = ref.watch(navigationProvider);
    final isScreenActive = nav.selectedUser == null &&
        nav.selectedHashtag == null &&
        nav.currentTab == MainTab.media;

    return feedAsync.when(
      data: (state) {
        final tweets = state.tweets;
        if (tweets.isEmpty) {
          if (state.isRefreshing) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching latest media...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }
          return _buildNoItemsState();
        }
        _managePool();
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: tweets.length,
              itemBuilder: (context, index) {
                final settings = ref.read(settingsProvider);
                return TiktokFeedItem(
                  tweet: tweets[index],
                  isVisible: index == _currentIndex && isScreenActive,
                  onPlaybackError: () {
                    if (index == _currentIndex && mounted) {
                      Future.delayed(
                          Duration(seconds: settings.autoSkipDelaySeconds), () {
                        if (mounted && _currentIndex == index) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    }
                  },
                );
              },
            ),
            if (state.isRefreshing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _buildErrorState(e),
    );
  }

  Widget _buildNoItemsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No media found.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _goToLogin(),
            child: const Text('Login to X'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _goToLogin(),
            child: const Text('Login to X'),
          ),
          TextButton(
            onPressed: () => ref.invalidate(feedNotifierProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToLogin() async {
    final success = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => const LoginScreen()),
    );
    if (success == true) {
      ref.invalidate(feedNotifierProvider);
    }
  }
}

class TiktokFeedItem extends ConsumerWidget {
  final Tweet tweet;
  final bool isVisible;
  final VoidCallback? onPlaybackError;

  const TiktokFeedItem({
    super.key,
    required this.tweet,
    required this.isVisible,
    this.onPlaybackError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return RepaintBoundary(
      child: Stack(
        children: [
          TiktokMediaContainer(
            tweet: tweet,
            isVisible: isVisible,
            overlayBuilder: (context, onFullscreen) => TweetTextOverlay(
              tweet: tweet,
              onFullscreen: onFullscreen,
            ),
            onPlaybackError: onPlaybackError,
          ),
          if (settings.showDebugInfo) DiscoveryDebugOverlay(tweet: tweet),
        ],
      ),
    );
  }
}

class DiscoveryDebugOverlay extends StatelessWidget {
  final Tweet tweet;
  const DiscoveryDebugOverlay({super.key, required this.tweet});

  Future<(int, int)> _fetchDebugStats() async {
    final mediaCount = await Repository.getMediaPlayedCount(tweet.id);
    final userCount = await Repository.getUserPlayedCount(tweet.userHandle);
    return (mediaCount, userCount);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 10,
      child: FutureBuilder<(int, int)>(
        future: _fetchDebugStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? (0, 0);
          return Card(
            color: Colors.black.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _debugLine('TYPE', tweet.isVideo ? 'VIDEO' : 'IMAGE'),
                  _debugLine('SOURCE', tweet.source ?? 'UNKNOWN'),
                  _debugLine('ID', tweet.id.substring(tweet.id.length - 8)),
                  _debugLine('MEDIA', '${tweet.mediaUrls.length} urls'),
                  _debugLine('SEEN', '${stats.$1} times'),
                  _debugLine('ACCT_SEEN', '${stats.$2} times'),
                  if (tweet.createdAt != null)
                    _debugLine(
                        'TS',
                        tweet.createdAt!
                            .toLocal()
                            .toString()
                            .split(' ')
                            .last
                            .split('.')
                            .first),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _debugLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
