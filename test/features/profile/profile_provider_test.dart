import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/profile/profile_provider.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/features/settings/settings_provider.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/database/repository.dart';
import 'package:xflow/core/models/tweet.dart';

import 'profile_provider_test.mocks.dart';

@GenerateMocks([TwitterClient])
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

  group('UserMediaNotifier Tests', () {
    test('loads local data immediately and then updates from API', () async {
      final localTweet = Tweet(
        id: 'local_1',
        text: 'Local Tweet',
        userHandle: '@$testHandle',
        mediaUrls: ['url1'],
        isVideo: true,
      );

      final apiTweet = Tweet(
        id: 'api_1',
        text: 'API Tweet',
        userHandle: '@$testHandle',
        mediaUrls: ['url2'],
        isVideo: true,
      );

      await Repository.insertCachedMedia([localTweet]);

      when(mockClient.fetchUserTimelineByScreenName(
        any,
        cursor: anyNamed('cursor'),
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
        tweets: [apiTweet],
        cursorBottom: 'new_cursor',
      ));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );

      // Initial read - should be local data
      // Await future to ensure build() completes
      await container.read(userMediaNotifierProvider(testHandle).future);
      
      final state1 = container.read(userMediaNotifierProvider(testHandle));
      expect(state1.value?.tweets.length, 1);
      expect(state1.value?.tweets.first.id, 'local_1');

      // Wait for refresh
      await Future.delayed(const Duration(milliseconds: 200));

      final state2 = container.read(userMediaNotifierProvider(testHandle));
      expect(state2.value?.tweets.length, 2);
      expect(state2.value?.cursorBottom, 'new_cursor');
    });

    test('updates only cursor if no new tweets found', () async {
      final localTweet = Tweet(
        id: 'local_1',
        text: 'Local Tweet',
        userHandle: '@$testHandle',
        mediaUrls: ['url1'],
        isVideo: true,
      );

      await Repository.insertCachedMedia([localTweet]);

      when(mockClient.fetchUserTimelineByScreenName(
        any,
        cursor: anyNamed('cursor'),
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
        tweets: [localTweet],
        cursorBottom: 'updated_cursor',
      ));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );

      await container.read(userMediaNotifierProvider(testHandle).future);
      await Future.delayed(const Duration(milliseconds: 200));

      final state = container.read(userMediaNotifierProvider(testHandle));
      expect(state.value?.tweets.length, 1);
      expect(state.value?.cursorBottom, 'updated_cursor');
    });
   group('Infinite Scroll Tests', () {
    test('fetchMore appends to state and saves to DB', () async {
      final existingTweet = Tweet(
        id: '1',
        text: 'Exist',
        userHandle: '@$testHandle',
        mediaUrls: ['u1'],
        isVideo: true,
      );

      final moreTweet = Tweet(
        id: '2',
        text: 'More',
        userHandle: '@$testHandle',
        mediaUrls: ['u2'],
        isVideo: true,
      );

      await Repository.insertCachedMedia([existingTweet]);

      when(mockClient.fetchUserTimelineByScreenName(
        any,
        cursor: anyNamed('cursor'),
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
        tweets: [moreTweet],
        cursorBottom: 'next_cursor',
      ));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );

      final notifier = container.read(userMediaNotifierProvider(testHandle).notifier);
      
      // Wait for initial build to finish
      await container.read(userMediaNotifierProvider(testHandle).future);
      // Wait for background refresh
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Now fetch more
      await notifier.fetchMore();

      final state = container.read(userMediaNotifierProvider(testHandle));
      expect(state.value?.tweets.length, 2);
      expect(state.value?.tweets.last.id, '2');
      expect(state.value?.cursorBottom, 'next_cursor');

      // Verify DB
      final dbItems = await Repository.getUserCachedMedia(testHandle, 10);
      expect(dbItems.any((t) => t.id == '2'), isTrue);
    });
  });
  });
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState();
}
