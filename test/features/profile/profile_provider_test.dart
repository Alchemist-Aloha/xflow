import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/profile/profile_provider.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/database/entities.dart';
import 'package:xflow/core/database/media_repository.dart';
import 'package:xflow/core/models/tweet.dart';

import 'profile_provider_test.mocks.dart';

@GenerateMocks([TwitterClient, MediaRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockTwitterClient mockClient;
  late MockMediaRepository mockRepo;
  const testHandle = 'testuser';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockTwitterClient();
    mockRepo = MockMediaRepository();
  });

  group('UserMediaNotifier Tests (Pure Mocked)', () {
    test('loads from cache and then merges API data', () async {
      final localTweet = Tweet(
        id: 'local_1',
        text: 'Local Tweet',
        userHandle: '@$testHandle',
        mediaUrls: ['url1'],
        isVideo: true,
        createdAt: DateTime(2023, 1, 1),
      );

      final apiTweet = Tweet(
        id: 'api_1',
        text: 'API Tweet',
        userHandle: '@$testHandle',
        mediaUrls: ['url2'],
        isVideo: true,
        createdAt: DateTime(2023, 1, 2),
      );

      when(mockClient.fetchProfile(testHandle)).thenAnswer(
        (_) async => Subscription(
          id: 'user_rest_id',
          screenName: testHandle,
          name: 'Test User',
        ),
      );
      when(mockRepo.getUserCachedMedia(any, any))
          .thenAnswer((_) async => [localTweet]);
      when(mockRepo.insertCachedMedia(any)).thenAnswer((_) async => {});

      final completer = Completer<TweetResponse>();
      when(mockClient.fetchUserTimeline(
        'user_rest_id',
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) => completer.future);

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          mediaRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      // Initial read - triggers build()
      final state =
          await container.read(userMediaNotifierProvider(testHandle).future);

      expect(state.tweets.length, 1);
      expect(state.tweets.first.id, 'local_1');
      expect(state.isRefreshing, isTrue);

      // Complete API
      completer.complete(TweetResponse(
        tweets: [apiTweet],
        cursorBottom: 'new_cursor',
      ));

      // Wait for background fetch (async)
      await Future.delayed(const Duration(milliseconds: 10));
      // Riverpod update might take a few microtasks
      await Future.delayed(const Duration(milliseconds: 10));

      final finalState =
          container.read(userMediaNotifierProvider(testHandle)).value!;
      expect(finalState.tweets.length, 2);
      expect(finalState.tweets.any((t) => t.id == 'api_1'), isTrue);
      expect(finalState.isRefreshing, isFalse);
    });

    test('uses id-based user timeline when local-first cache is empty',
        () async {
      final apiTweet = Tweet(
        id: 'api_from_timeline',
        text: 'Timeline Tweet',
        userHandle: '@RealCaseUser',
        mediaUrls: ['url2'],
        isVideo: true,
        createdAt: DateTime(2023, 1, 2),
      );

      when(mockRepo.getUserCachedMedia(any, any)).thenAnswer((_) async => []);
      when(mockRepo.insertCachedMedia(any)).thenAnswer((_) async => {});
      when(mockClient.fetchProfile('realcaseuser')).thenAnswer(
        (_) async => Subscription(
          id: 'real_user_id',
          screenName: 'RealCaseUser',
          name: 'Real Case User',
        ),
      );
      when(mockClient.fetchUserTimeline(
        'real_user_id',
        cooldownMinutes: anyNamed('cooldownMinutes'),
      )).thenAnswer((_) async => TweetResponse(
            tweets: [apiTweet],
            cursorBottom: 'timeline_cursor',
          ));

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          mediaRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final firstState = await container
          .read(userMediaNotifierProvider('realcaseuser').future);
      expect(firstState.tweets, isEmpty);
      expect(firstState.isRefreshing, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final finalState =
          container.read(userMediaNotifierProvider('realcaseuser')).value!;
      expect(finalState.tweets.map((t) => t.id), contains('api_from_timeline'));
      expect(finalState.cursorBottom, 'timeline_cursor');
      verifyNever(mockClient.fetchUserTimelineByScreenName(any,
          cooldownMinutes: anyNamed('cooldownMinutes')));
    });
  });
}
