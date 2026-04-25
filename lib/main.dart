import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'features/feed/tiktok_feed_screen.dart';
import 'features/feed/tweet_detail_screen.dart';
import 'features/feed/hashtag_feed_screen.dart';
import 'features/subscriptions/subscription_list_screen.dart';
import 'features/profile/user_details_screen.dart';
import 'features/profile/user_media_feed_screen.dart';
import 'core/navigation/navigation_provider.dart';
import 'core/client/background_sync.dart';
import 'core/client/twitter_client.dart';
import 'features/settings/settings_provider.dart';
import 'core/client/twitter_account.dart';
import 'core/database/repository.dart';
import 'core/utils/lifecycle_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Future.wait([
    TwitterAccount.init(),
    Repository.database,
  ]);

  runApp(const ProviderScope(child: XFlowApp()));
}

class XFlowApp extends ConsumerWidget {
  const XFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to lifecycle changes
    ref.listen(lifecycleProvider, (previous, next) {
      if (next == AppLifecycle.resumed) {
        debugPrint('XFLOW: App resumed. Ensuring BackgroundSync is active.');
        TwitterClient.resetQueue();
        BackgroundSync.restart(TwitterClient(), ref.read(settingsProvider));
      }
    });

    ref.listen(settingsProvider, (prev, next) {
      if (prev?.syncInterval != next.syncInterval ||
          prev?.syncBatchSize != next.syncBatchSize ||
          prev?.pruneThreshold != next.pruneThreshold) {
        BackgroundSync.restart(TwitterClient(), next);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackgroundSync.start(TwitterClient(), ref.read(settingsProvider));
    });

    return MaterialApp(
      title: 'XFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Colors.blue.withOpacity(0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    final mainScreens = IndexedStack(
      index: nav.currentTab.index,
      children: const [
        TiktokFeedScreen(),
        SubscriptionListScreen(isStandalone: false),
        HashtagFeedScreen(hashtag: '#trending', showBackButton: false),
      ],
    );

    Widget? overlayScreen;
    if (nav.selectedHashtag != null && nav.currentTab != MainTab.trending) {
      overlayScreen = HashtagFeedScreen(hashtag: nav.selectedHashtag!);
    } else if (nav.selectedTweet != null) {
      overlayScreen = TweetDetailScreen(tweet: nav.selectedTweet!);
    } else if (nav.selectedUser != null) {
      if (nav.userMediaInitialIndex != null) {
        overlayScreen = UserMediaFeedScreen(
          screenName: nav.selectedUser!,
          initialIndex: nav.userMediaInitialIndex!,
        );
      } else {
        overlayScreen = UserDetailsScreen(screenName: nav.selectedUser!);
      }
    }

    final body = Stack(
      children: [
        Visibility(
          visible: overlayScreen == null,
          maintainState: true,
          child: mainScreens,
        ),
        if (overlayScreen != null)
          Container(
            color: Colors.black,
            child: overlayScreen,
          ),
      ],
    );

    return PopScope(
      canPop: nav.selectedUser == null &&
          nav.selectedTweet == null &&
          nav.selectedHashtag == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          navNotifier.back();
        }
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: nav.currentTab.index,
          onDestinationSelected: (index) {
            navNotifier.setTab(MainTab.values[index]);
            if (index == 1) {
              ref.invalidate(subscriptionListProvider);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library, color: Colors.blue),
              label: 'Media',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people, color: Colors.blue),
              label: 'Subscriptions',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up_outlined),
              selectedIcon: Icon(Icons.trending_up, color: Colors.blue),
              label: 'Trending',
            ),
          ],
        ),
      ),
    );
  }
}
