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

  const UserMediaFeedScreen({
    super.key,
    required this.screenName,
    required this.initialIndex,
  });

  @override
  ConsumerState<UserMediaFeedScreen> createState() =>
      _UserMediaFeedScreenState();
}

class _UserMediaFeedScreenState extends ConsumerState<UserMediaFeedScreen> {
  late PageController _pageController;
  late int _currentIndex;

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
        if (page >= tweets.length - 5) {
          ref
              .read(userMediaNotifierProvider(widget.screenName).notifier)
              .fetchMore();
        }
      }
    }
  }

  void _managePool() {
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

        if (tweet.isVideo) {
          pool.warmup(tweet.id, tweet.mediaUrls.first);
        } else if (tweet.mediaUrls.isNotEmpty) {
          for (final url in tweet.mediaUrls) {
            precacheImage(NetworkImage(url), context);
          }
        }
      }
    }
    pool.cleanupExcept(activeIds);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(userMediaNotifierProvider(widget.screenName));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(navigationProvider.notifier).back(),
        ),
        title: Text('@${widget.screenName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: feedAsync.when(
        data: (state) {
          final tweets = state.tweets;
          if (tweets.isEmpty) {
            return const Center(
                child: Text('No media found.',
                    style: TextStyle(color: Colors.white70)));
          }

          _managePool();

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: tweets.length,
            itemBuilder: (context, index) {
              final settings = ref.read(settingsProvider);
              return UserMediaFeedItem(
                tweet: tweets[index],
                isVisible: index == _currentIndex,
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white70))),
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
        overlay: TweetTextOverlay(tweet: tweet),
        onPlaybackError: onPlaybackError,
      ),
    );
  }
}
