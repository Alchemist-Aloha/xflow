import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/navigation_provider.dart';
import '../player/player_pool_provider.dart';
import 'profile_provider.dart';
import '../player/widgets/media_container.dart';
import '../../core/models/tweet.dart';
import '../feed/widgets/tweet_text_overlay.dart';
import '../settings/settings_provider.dart';

class UserMediaFeedScreen extends ConsumerStatefulWidget {
  final String screenName;
  final int initialIndex;
  final String? initialTweetId;

  const UserMediaFeedScreen({
    super.key,
    required this.screenName,
    required this.initialIndex,
    this.initialTweetId,
  });

  @override
  ConsumerState<UserMediaFeedScreen> createState() =>
      _UserMediaFeedScreenState();
}

class _UserMediaFeedScreenState extends ConsumerState<UserMediaFeedScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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

      final feedAsync = ref.read(userMediaNotifierProvider(widget.screenName));
      if (feedAsync.hasValue) {
        final tweets = feedAsync.value!.tweets;
        final settings = ref.read(settingsProvider);
        if (page >= tweets.length - settings.lazyLoadThreshold &&
            !feedAsync.value!.isLoadingMore) {
          ref
              .read(userMediaNotifierProvider(widget.screenName).notifier)
              .fetchMore();
        }
      }
    }
  }

  void _managePool() {
    // Use a microtask to avoid building-phase conflicts
    Future.microtask(() {
      if (!mounted) return;
      final feedAsync = ref.read(userMediaNotifierProvider(widget.screenName));
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(userMediaNotifierProvider(widget.screenName));

    // Listen for data arrival to handle initial index adjustment if list shifted
    ref.listen(userMediaNotifierProvider(widget.screenName), (prev, next) {
      if (next.hasValue && !_initialized) {
        final tweets = next.value!.tweets;
        int targetIndex = widget.initialIndex;

        if (widget.initialTweetId != null) {
          final foundIndex =
              tweets.indexWhere((t) => t.id == widget.initialTweetId);
          if (foundIndex != -1) {
            targetIndex = foundIndex;
          }
        }

        if (targetIndex < tweets.length) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(targetIndex);
          }
          setState(() {
            _currentIndex = targetIndex;
          });
        }
        _initialized = true;
      }

      // Always manage pool when data changes
      if (next.hasValue) {
        _managePool();
      }
    });
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => ref.read(navigationProvider.notifier).back(),
        ),
        title: Text('@${widget.screenName}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref
                .read(userMediaNotifierProvider(widget.screenName).notifier)
                .refresh(),
          ),
        ],
      ),
      body: feedAsync.when(
        data: (state) {
          final tweets = state.tweets;
          if (tweets.isEmpty) {
            if (state.isRefreshing) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No media found.',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(userMediaNotifierProvider(widget.screenName)
                            .notifier)
                        .refresh(),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // Ensure pool is warmed up for current view
          _managePool();

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: tweets.length,
                itemBuilder: (context, index) {
                  final settings = ref.read(settingsProvider);
                  final tweet = tweets[index];
                  return UserMediaFeedItem(
                    key: ValueKey('user_feed_${tweet.id}'),
                    tweet: tweet,
                    isVisible: index == _currentIndex,
                    onPlaybackError: () {
                      if (index == _currentIndex && mounted) {
                        Future.delayed(
                            Duration(seconds: settings.autoSkipDelaySeconds),
                            () {
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(userMediaNotifierProvider(widget.screenName).notifier)
                    .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserMediaFeedItem extends StatelessWidget {
  final Tweet tweet;
  final bool isVisible;
  final VoidCallback? onPlaybackError;

  const UserMediaFeedItem({
    super.key,
    required this.tweet,
    required this.isVisible,
    this.onPlaybackError,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TiktokMediaContainer(
        tweet: tweet,
        isVisible: isVisible,
        overlayBuilder: (context, onFullscreen) => TweetTextOverlay(
          tweet: tweet,
          onFullscreen: onFullscreen,
        ),
        onPlaybackError: onPlaybackError,
      ),
    );
  }
}
