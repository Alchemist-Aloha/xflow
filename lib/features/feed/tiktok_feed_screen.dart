import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/player_pool_provider.dart';
import 'feed_provider.dart';
import '../player/widgets/media_container.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_screen.dart';
import '../auth/login_screen.dart';
import '../../core/client/twitter_account.dart';
import '../profile/user_details_screen.dart';
import '../subscriptions/subscription_list_screen.dart';
import 'widgets/tweet_text_overlay.dart';

class TiktokFeedScreen extends ConsumerStatefulWidget {
  const TiktokFeedScreen({super.key});

  @override
  ConsumerState<TiktokFeedScreen> createState() => _TiktokFeedScreenState();
}

class _TiktokFeedScreenState extends ConsumerState<TiktokFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  int _navigationIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handleScroll);
    _initAuth();
  }

  Future<void> _initAuth() async {
    await TwitterAccount.init();
    if (mounted) {
      ref.invalidate(feedProvider);
    }
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
        if (page >= tweets.length - 3) {
          ref.read(feedNotifierProvider.notifier).fetchMore();
        }
      }
    }
  }

  void _managePool() {
    final feedAsync = ref.read(feedNotifierProvider);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopPanel(),
            Expanded(
              child: IndexedStack(
                index: _navigationIndex,
                children: [
                  _buildMediaFeed(),
                  const SubscriptionListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navigationIndex,
        onTap: (index) {
          setState(() {
            _navigationIndex = index;
          });
          if (index == 1) {
             ref.invalidate(subscriptionListProvider);
          }
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Media'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Subscriptions'),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    String title = "Subscriptions";
    if (_navigationIndex == 1) {
      title = "My Subscriptions";
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              if (_navigationIndex == 0) {
                ref.invalidate(feedNotifierProvider);
              } else {
                ref.invalidate(subscriptionListProvider);
              }
            },
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaFeed() {
    final feedAsync = ref.watch(feedNotifierProvider);
    return feedAsync.when(
      data: (state) {
        final tweets = state.tweets;
        if (tweets.isEmpty) {
          return _buildNoItemsState();
        }
        _managePool();
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
      error: (e, st) => _buildErrorState(e),
    );
  }

  Widget _buildNoItemsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No media found.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
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
          Text('Error: $e', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
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

class TiktokFeedItem extends StatelessWidget {
  final Tweet tweet;
  final bool isVisible;

  const TiktokFeedItem({super.key, required this.tweet, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TiktokMediaContainer(tweet: tweet, isVisible: isVisible),
        TweetTextOverlay(tweet: tweet),
      ],
    );
  }
}
