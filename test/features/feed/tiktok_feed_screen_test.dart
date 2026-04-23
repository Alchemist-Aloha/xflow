import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xflow/features/feed/tiktok_feed_screen.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:xflow/features/player/player_pool_provider.dart';

import 'package:xflow/core/client/twitter_client.dart';
import 'package:mockito/annotations.dart';
import 'tiktok_feed_screen_test.mocks.dart';

@GenerateMocks([TwitterClient])
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('TiktokFeedScreen Widget Tests', () {
    testWidgets('renders feed items from mock provider', (WidgetTester tester) async {
      final mockTweets = [
        Tweet(
          id: '1',
          text: 'Feed Item 1',
          userHandle: 'user1',
          mediaUrls: ['https://test.com/v1.mp4'],
          isVideo: true,
        ),
      ];

      final mockState = FeedState(tweets: mockTweets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedNotifierProvider.overrideWith(() => MockFeedNotifier(mockState)),
            playerPoolProvider.overrideWith(() => MockPlayerPool()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TiktokFeedScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Check if PageView is present
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}

class MockFeedNotifier extends FeedNotifier {
  final FeedState mockState;
  MockFeedNotifier(this.mockState);

  @override
  FutureOr<FeedState> build() => mockState;

  @override
  Future<void> fetchMore() async {}
}

class MockPlayerPool extends PlayerPoolNotifier {
  @override
  Map<String, PlayerInstance> build() => {};
  @override
  void warmup(String id, String url, {bool isLandscape = false}) {}
  @override
  void cleanupExcept(Set<String> activeIds) {}
}
