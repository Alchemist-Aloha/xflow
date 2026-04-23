import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/player_pool_provider.dart';
import 'profile_provider.dart';
import '../player/widgets/media_container.dart';
import '../../core/models/tweet.dart';

class UserMediaFeedScreen extends ConsumerStatefulWidget {
  final String screenName;
  final int initialIndex;

  const UserMediaFeedScreen({
    super.key,
    required this.screenName,
    required this.initialIndex,
  });

  @override
  ConsumerState<UserMediaFeedScreen> createState() => _UserMediaFeedScreenState();
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

      // Check if we need to fetch more
      final feedAsync = ref.read(userMediaNotifierProvider(widget.screenName));
      if (feedAsync.hasValue) {
        final tweets = feedAsync.value!.tweets;
        if (page >= tweets.length - 3) {
          ref.read(userMediaNotifierProvider(widget.screenName).notifier).fetchMore();
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

    for (int i = _currentIndex - 1; i <= _currentIndex + 2; i++) {
      if (i >= 0 && i < tweets.length) {
        final tweet = tweets[i];
        activeIds.add(tweet.id);
        if (tweet.isVideo) {
          pool.warmup(tweet.id, tweet.mediaUrls.first);
        }
      }
    }
    pool.cleanupExcept(activeIds);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(userMediaNotifierProvider(widget.screenName));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          feedAsync.when(
            data: (state) {
              final tweets = state.tweets;
              if (tweets.isEmpty) {
                return const Center(child: Text('No media found.', style: TextStyle(color: Colors.white70)));
              }
              
              _managePool();

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: tweets.length,
                itemBuilder: (context, index) {
                  return UserMediaFeedItem(
                    tweet: tweets[index],
                    isVisible: index == _currentIndex,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserMediaFeedItem extends StatelessWidget {
  final Tweet tweet;
  final bool isVisible;

  const UserMediaFeedItem({super.key, required this.tweet, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TiktokMediaContainer(tweet: tweet, isVisible: isVisible),
        _buildUIOverlay(),
      ],
    );
  }

  Widget _buildUIOverlay() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tweet.userHandle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            tweet.text,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
