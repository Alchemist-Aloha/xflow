import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/profile/profile_provider.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/database/entities.dart';
import 'package:xflow/core/database/repository.dart';
import 'package:xflow/core/models/tweet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late TestTwitterClient mockClient;
  const testHandle = 'testuser';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClient = TestTwitterClient();
    await Repository.close();
  });

  tearDown(() async {
    await Repository.close();
  });

  group('UserMediaNotifier Tests', () {
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

      await Repository.insertCachedMedia([localTweet]);
      mockClient.profileByScreenName[testHandle] = Subscription(
        id: 'user_rest_id',
        screenName: testHandle,
        name: 'Test User',
      );
      mockClient.timelineByUserId['user_rest_id'] = Future.value(
        TweetResponse(
          tweets: [apiTweet],
          cursorBottom: 'new_cursor',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(userMediaNotifierProvider(testHandle));
      await _waitFor(
        () =>
            container
                .read(userMediaNotifierProvider(testHandle))
                .value
                ?.tweets
                .length ==
            2,
      );

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

      mockClient.profileByScreenName['realcaseuser'] = Subscription(
        id: 'real_user_id',
        screenName: 'RealCaseUser',
        name: 'Real Case User',
      );
      mockClient.timelineByUserId['real_user_id'] = Future.value(
        TweetResponse(
          tweets: [apiTweet],
          cursorBottom: 'timeline_cursor',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(userMediaNotifierProvider('realcaseuser'));
      await _waitFor(
        () =>
            container
                .read(userMediaNotifierProvider('realcaseuser'))
                .value
                ?.tweets
                .any((tweet) => tweet.id == 'api_from_timeline') ==
            true,
      );

      final finalState =
          container.read(userMediaNotifierProvider('realcaseuser')).value!;
      expect(finalState.tweets.map((t) => t.id), contains('api_from_timeline'));
      expect(mockClient.fetchUserTimelineByScreenNameCalls, isEmpty);
    });
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 20; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(predicate(), isTrue);
}

class TestTwitterClient extends TwitterClient {
  final profileByScreenName = <String, Subscription?>{};
  final timelineByUserId = <String, Future<TweetResponse>>{};
  final timelineByScreenName = <String, Future<TweetResponse>>{};
  final fetchUserTimelineByScreenNameCalls = <String>[];

  @override
  Future<Subscription?> fetchProfile(String screenName) async {
    return profileByScreenName[screenName];
  }

  @override
  Future<TweetResponse> fetchUserTimeline(
    String userId, {
    String? cursor,
    int cooldownMinutes = 15,
    int count = 20,
    int timeoutSeconds = 15,
  }) async {
    return timelineByUserId[userId] ?? Future.value(TweetResponse(tweets: []));
  }

  @override
  Future<TweetResponse> fetchUserTimelineByScreenName(
    String screenName, {
    String? cursor,
    int cooldownMinutes = 15,
  }) async {
    fetchUserTimelineByScreenNameCalls.add(screenName);
    return timelineByScreenName[screenName] ??
        Future.value(TweetResponse(tweets: []));
  }
}
