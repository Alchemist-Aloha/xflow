import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/player_pool_provider.dart';
import 'feed_provider.dart';
import '../player/widgets/media_container.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_screen.dart'; // Add this

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
    }
  }

  void _managePool() {
    final feedAsync = ref.read(feedProvider);
    final feed = feedAsync.value;
    if (feed == null) return;

    // Warmup next items
    final pool = ref.read(playerPoolProvider.notifier);
    final activeIds = <String>{};

    for (int i = _currentIndex - 1; i <= _currentIndex + 2; i++) {
      if (i >= 0 && i < feed.length) {
        final tweet = feed[i];
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
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          feedAsync.when(
            data: (tweets) {
              // Trigger initial warmup
              WidgetsBinding.instance.addPostFrameCallback((_) => _managePool());

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: tweets.length,
                itemBuilder: (context, index) {
                  return TiktokFeedItem(
                    tweet: tweets[index],
                    isVisible: index == _currentIndex,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TiktokFeedItem extends StatelessWidget {
  final Tweet tweet;
  final bool isVisible;

  const TiktokFeedItem({super.key, required this.tweet, required this.isVisible});

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
