# XFlow TikTok Feed UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the vertical scrolling feed using `PageView.builder`, integrate the `PlayerPoolProvider` for windowed prefetching, and add TikTok-style UI overlays.

**Architecture:** A `TiktokFeedScreen` will manage a `PageController`. It will listen to scroll events to update the `playerPoolProvider`'s "warmup" and "cleanup" methods. Each page will be a `TiktokFeedItem` containing the `TiktokMediaContainer` and UI overlays.

**Tech Stack:** Flutter, Riverpod, Material 3

---

### Task 1: Implement Feed Provider & Screen

**Files:**
- Create: `lib/features/feed/feed_provider.dart`
- Create: `lib/features/feed/tiktok_feed_screen.dart`

- [ ] **Step 1: Create the `FeedProvider`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';

final twitterClientProvider = Provider((ref) => TwitterClient());

final feedProvider = FutureProvider<List<Tweet>>((ref) async {
  final client = ref.watch(twitterClientProvider);
  return client.fetchTrendingMedia();
});
```

- [ ] **Step 2: Create the `TiktokFeedScreen` with vertical `PageView`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/player_pool_provider.dart';
import 'feed_provider.dart';
import '../player/widgets/media_container.dart';

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
    final feed = ref.read(feedProvider).value;
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
      body: feedAsync.when(
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
```

- [ ] **Step 3: Update `lib/main.dart` to show `TiktokFeedScreen`**

```dart
// ... imports
import 'features/feed/tiktok_feed_screen.dart';

// ... in XFlowApp build:
      home: const TiktokFeedScreen(),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/feed/ lib/main.dart
git commit -m "feat: implement tiktok feed screen and provider"
```
