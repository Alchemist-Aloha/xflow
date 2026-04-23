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

  group('UserMediaNotifier Tests (Online Only Initial Load)', () {
    test('loads from API directly and ignores initial cache', () async {
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
        testHandle,
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

      // Initial read - should be API data directly, bypassing local cache
      final state = await container.read(userMediaNotifierProvider(testHandle).future);
      
      expect(state.tweets.length, 1);
      expect(state.tweets.first.id, 'api_1');
      expect(state.cursorBottom, 'new_cursor');
      expect(state.isRefreshing, isFalse);

      // Verify it saved to DB
      final dbItems = await Repository.getUserCachedMedia(testHandle, 10);
      expect(dbItems.any((t) => t.id == 'api_1'), isTrue);
    });

    test('falls back to cache on API error', () async {
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
      )).thenThrow(Exception('API Down'));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );

      final state = await container.read(userMediaNotifierProvider(testHandle).future);
      
      // Should fallback to local cache
      expect(state.tweets.length, 1);
      expect(state.tweets.first.id, 'local_1');
    });

   group('Infinite Scroll Tests', () {
    test('fetchMore appends to state and saves to DB', () async {
      final apiTweet1 = Tweet(
        id: 'api_1',
        text: 'API 1',
        userHandle: '@$testHandle',
        mediaUrls: ['u1'],
        isVideo: true,
      );

      final apiTweet2 = Tweet(
        id: 'api_2',
        text: 'API 2',
        userHandle: '@$testHandle',
        mediaUrls: ['u2'],
        isVideo: true,
      );

      // Build calls this for first load
      when(mockClient.fetchUserTimelineByScreenName(
        testHandle,
        cursor: null,
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
        tweets: [apiTweet1],
        cursorBottom: 'cursor_1',
      ));

      // fetchMore calls this
      when(mockClient.fetchUserTimelineByScreenName(
        testHandle,
        cursor: 'cursor_1',
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
        tweets: [apiTweet2],
        cursorBottom: 'cursor_2',
      ));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );

      final notifier = container.read(userMediaNotifierProvider(testHandle).notifier);
      
      // Initial build
      await container.read(userMediaNotifierProvider(testHandle).future);
      
      // Now fetch more
      await notifier.fetchMore();

      final state = container.read(userMediaNotifierProvider(testHandle));
      expect(state.value?.tweets.length, 2);
      expect(state.value?.tweets.first.id, 'api_1');
      expect(state.value?.tweets.last.id, 'api_2');
      expect(state.value?.cursorBottom, 'cursor_2');
    });
  });
  });
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState();
}
