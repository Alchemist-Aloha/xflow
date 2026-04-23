import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'features/feed/tiktok_feed_screen.dart';
import 'features/subscriptions/subscription_list_screen.dart';
import 'features/profile/user_details_screen.dart';
import 'features/profile/user_media_feed_screen.dart';
import 'core/navigation/navigation_provider.dart';
import 'core/client/background_sync.dart';
import 'core/client/twitter_client.dart';
import 'features/settings/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  runApp(const ProviderScope(child: XFlowApp()));
}

class XFlowApp extends ConsumerWidget {
  const XFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Manage BackgroundSync lifecycle
    ref.listen(settingsProvider.select((s) => s.syncInterval), (prev, next) {
      BackgroundSync.restart(TwitterClient(), ref.read(settingsProvider));
    });

    // Start on boot if not already started
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackgroundSync.start(TwitterClient(), ref.read(settingsProvider));
    });

    return MaterialApp(
      title: 'XFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
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
      ],
    );

    Widget? overlayScreen;
    if (nav.selectedUser != null) {
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
        Offstage(
          offstage: overlayScreen != null,
          child: mainScreens,
        ),
        if (overlayScreen != null) overlayScreen,
      ],
    );

    // Handle back button
    return PopScope(
      canPop: nav.selectedUser == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          navNotifier.back();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: body,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: nav.currentTab.index,
          onTap: (index) {
            navNotifier.setTab(MainTab.values[index]);
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
      ),
    );
  }
}
