import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/profile/user_details_screen.dart';
import 'package:xflow/features/profile/profile_provider.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/features/settings/settings_provider.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/database/repository.dart';
import 'package:xflow/core/database/entities.dart';
import 'package:xflow/core/models/tweet.dart';

import 'profile_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockTwitterClient mockClient;
  const testHandle = 'testuser';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockTwitterClient();
    final db = await Repository.database;
    await db.delete('cached_media');
    await db.delete('subscriptions');
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        twitterClientProvider.overrideWithValue(mockClient),
        // We don't override settingsProvider here to use default values
      ],
      child: MaterialApp(
        home: const UserDetailsScreen(screenName: testHandle),
      ),
    );
  }

  testWidgets('shows loading indicator then user not found', (tester) async {
    when(mockClient.fetchProfile(testHandle)).thenAnswer((_) async => null);
    when(mockClient.fetchUserTimelineByScreenName(any, cooldownMinutes: anyNamed('cooldownMinutes')))
        .thenAnswer((_) async => TweetResponse(tweets: []));

    await tester.pumpWidget(createTestWidget());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('User not found'), findsOneWidget);
  });

  testWidgets('shows profile info and empty media state', (tester) async {
    final profile = Subscription(
      id: '123',
      screenName: testHandle,
      name: 'Test User',
      description: 'A test user description',
      followersCount: 1000,
      followingCount: 500,
    );

    when(mockClient.fetchProfile(testHandle)).thenAnswer((_) async => profile);
    when(mockClient.fetchUserTimelineByScreenName(any, cooldownMinutes: anyNamed('cooldownMinutes')))
        .thenAnswer((_) async => TweetResponse(tweets: []));

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsWidgets);
    expect(find.text('@$testHandle'), findsOneWidget);
    expect(find.text('A test user description'), findsOneWidget);
    expect(find.text('1.0K'), findsOneWidget); // Followers
    expect(find.text('500'), findsOneWidget); // Following
    expect(find.text('No media found'), findsOneWidget);
  });

  testWidgets('cache-first: shows cached items while fetching fresh data', (tester) async {
    final profile = Subscription(
      id: '123',
      screenName: testHandle,
      name: 'Test User',
    );

    final cachedTweet = Tweet(
      id: 'cached_1',
      text: 'Cached Content',
      userHandle: '@$testHandle',
      mediaUrls: ['url1'],
      isVideo: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    final freshTweet = Tweet(
      id: 'fresh_1',
      text: 'Fresh Content',
      userHandle: '@$testHandle',
      mediaUrls: ['url2'],
      isVideo: true,
      createdAt: DateTime.now(),
    );

    // Seed cache
    await Repository.insertCachedMedia([cachedTweet]);

    when(mockClient.fetchProfile(testHandle)).thenAnswer((_) async => profile);
    
    // Return fresh data with a delay
    when(mockClient.fetchUserTimelineByScreenName(any, cooldownMinutes: anyNamed('cooldownMinutes')))
        .thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return TweetResponse(tweets: [freshTweet]);
    });

    await tester.pumpWidget(createTestWidget());
    
    // After profile loads but before fresh tweets load
    await tester.pump(); // Start fetching profile
    await tester.pump(const Duration(milliseconds: 100)); // Wait for profile fetch

    // Should show cached content
    expect(find.text('Cached Content'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget); // IsRefreshing indicator

    // Wait for fresh data
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Should show fresh content
    expect(find.text('Fresh Content'), findsOneWidget);
    expect(find.text('Cached Content'), findsNothing); // Merging logic in profile_provider.dart replaces or sorts
  });

  testWidgets('shows error message on API failure when no cache exists', (tester) async {
    when(mockClient.fetchProfile(testHandle)).thenThrow(Exception('Network Error'));

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('Error loading profile: Exception: Network Error'), findsOneWidget);
  });

  testWidgets('fetchMore: loads more items when scrolling to bottom', (tester) async {
    final profile = Subscription(
      id: '123',
      screenName: testHandle,
      name: 'Test User',
    );

    final initialTweets = List.generate(10, (i) => Tweet(
      id: 'id_$i',
      text: 'Tweet $i',
      userHandle: '@$testHandle',
      mediaUrls: ['url_$i'],
      isVideo: false,
      createdAt: DateTime.now().subtract(Duration(minutes: i)),
    ));

    final moreTweets = List.generate(5, (i) => Tweet(
      id: 'more_${i + 10}',
      text: 'More Tweet ${i + 10}',
      userHandle: '@$testHandle',
      mediaUrls: ['url_more_${i + 10}'],
      isVideo: false,
      createdAt: DateTime.now().subtract(Duration(minutes: i + 10)),
    ));

    when(mockClient.fetchProfile(testHandle)).thenAnswer((_) async => profile);
    
    // Initial fetch
    when(mockClient.fetchUserTimelineByScreenName(testHandle, cooldownMinutes: anyNamed('cooldownMinutes')))
        .thenAnswer((_) async => TweetResponse(
          tweets: initialTweets,
          cursorBottom: 'next_cursor',
        ));

    // Fetch more
    when(mockClient.fetchUserTimelineByScreenName(testHandle, cursor: 'next_cursor', cooldownMinutes: anyNamed('cooldownMinutes')))
        .thenAnswer((_) async => TweetResponse(
          tweets: moreTweets,
          cursorBottom: 'end_cursor',
        ));

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Tweet 0'), findsOneWidget);
    
    // Scroll to bottom
    final listFinder = find.byType(CustomScrollView);
    await tester.drag(listFinder, const Offset(0, -2000));
    await tester.pumpAndSettle();

    // Should have triggered fetchMore and now show more tweets
    expect(find.text('More Tweet 10'), findsOneWidget);
  });
}
