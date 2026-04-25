import 'dart:async';
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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockTwitterClient mockClient;
  const testHandle = 'testuser';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockTwitterClient();
    await Repository.close();
  });

  tearDown(() async {
    await Repository.close();
  });

  group('UserMediaNotifier Logic (Unit Tests)', () {
    test('initial build loads from cache and triggers fresh fetch', () async {
      final cachedTweet = Tweet(
          id: 'c1',
          text: 'Cached',
          userHandle: testHandle,
          mediaUrls: [],
          isVideo: false,
          createdAt: DateTime(2023, 1, 1));
      final freshTweet = Tweet(
          id: 'f1',
          text: 'Fresh',
          userHandle: testHandle,
          mediaUrls: [],
          isVideo: false,
          createdAt: DateTime(2023, 1, 2));

      await Repository.insertCachedMedia([cachedTweet]);

      when(mockClient.fetchUserTimelineByScreenName(any,
              cooldownMinutes: anyNamed('cooldownMinutes')))
          .thenAnswer((_) async => TweetResponse(tweets: [freshTweet]));

      final container = ProviderContainer(overrides: [
        twitterClientProvider.overrideWithValue(mockClient),
      ]);

      // Initial read triggers build()
      final firstState =
          await container.read(userMediaNotifierProvider(testHandle).future);
      expect(firstState.tweets.any((t) => t.id == 'c1'), isTrue);

      // Give the background fetch time to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final finalState =
          container.read(userMediaNotifierProvider(testHandle)).value!;
      expect(finalState.tweets.any((t) => t.id == 'f1'), isTrue);
      expect(finalState.isRefreshing, isFalse);
    });
  });

  group('UserDetailsScreen Widget Tests', () {
    testWidgets('shows loading state then profile name', (tester) async {
      final profile =
          Subscription(id: '1', screenName: testHandle, name: 'Display Name');
      when(mockClient.fetchProfile(testHandle))
          .thenAnswer((_) async => profile);
      when(mockClient.fetchUserTimelineByScreenName(any,
              cooldownMinutes: anyNamed('cooldownMinutes')))
          .thenAnswer((_) async => TweetResponse(tweets: []));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
        ],
        child: MaterialApp(
          home: const UserDetailsScreen(screenName: testHandle),
        ),
      ));

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Wait for profile fetch
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Display Name'), findsWidgets);
    });
  });
}
