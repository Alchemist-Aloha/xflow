import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/features/feed/hashtag_provider.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HashtagMediaNotifier', () {
    late _FakeTwitterClient mockClient;

    setUp(() {
      mockClient = _FakeTwitterClient();
    });

    test('falls back to latest media search when top search is empty',
        () async {
      final latestTweet = Tweet(
        id: 'hashtag_latest_1',
        text: 'Hashtag media',
        userHandle: '@creator',
        mediaUrls: ['https://test.com/hash.jpg'],
        createdAt: DateTime(2024, 1, 1),
      );

      mockClient.stub(
        query: '#nature (filter:images OR filter:videos)',
        sort: FeedSort.trending,
        response: TweetResponse(tweets: []),
      );
      mockClient.stub(
        query: '#nature (filter:images OR filter:videos)',
        sort: FeedSort.latest,
        response: TweetResponse(
          tweets: [latestTweet],
          cursorBottom: 'latest_cursor',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final state =
          await container.read(hashtagMediaProvider('#nature').future);

      expect(state.tweets.map((t) => t.id), contains('hashtag_latest_1'));
      expect(state.cursorBottom, 'latest_cursor');
    });

    test('falls back to plain hashtag search and keeps that query for paging',
        () async {
      final fallbackTweet = Tweet(
        id: 'hashtag_post_1',
        text: 'Plain hashtag post',
        userHandle: '@creator',
        mediaUrls: const [],
        createdAt: DateTime(2024, 1, 1),
      );
      final nextTweet = Tweet(
        id: 'hashtag_post_2',
        text: 'Next plain hashtag post',
        userHandle: '@creator2',
        mediaUrls: const [],
        createdAt: DateTime(2024, 1, 2),
      );

      mockClient.stub(
        query: '#nature (filter:images OR filter:videos)',
        sort: FeedSort.trending,
        response: TweetResponse(tweets: []),
      );
      mockClient.stub(
        query: '#nature (filter:images OR filter:videos)',
        sort: FeedSort.latest,
        response: TweetResponse(tweets: []),
      );
      mockClient.stub(
        query: '#nature',
        sort: FeedSort.latest,
        response: TweetResponse(
          tweets: [fallbackTweet],
          cursorBottom: 'plain_cursor',
        ),
      );
      mockClient.stub(
        query: '#nature',
        sort: FeedSort.latest,
        cursor: 'plain_cursor',
        response: TweetResponse(
          tweets: [nextTweet],
          cursorBottom: 'plain_cursor_2',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          twitterClientProvider.overrideWithValue(mockClient),
          settingsProvider.overrideWith(() => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(hashtagMediaProvider('#nature').notifier);
      final initialState =
          await container.read(hashtagMediaProvider('#nature').future);

      expect(initialState.tweets.map((t) => t.id), contains('hashtag_post_1'));
      expect(initialState.cursorBottom, 'plain_cursor');

      await notifier.fetchMore();

      final pagedState = container.read(hashtagMediaProvider('#nature')).value!;
      expect(
          pagedState.tweets.map((t) => t.id),
          containsAll([
            'hashtag_post_1',
            'hashtag_post_2',
          ]));
      expect(pagedState.cursorBottom, 'plain_cursor_2');
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      timelineBatchSize: 20,
      loadBatchSize: 20,
      cooldownDuration: 15,
    );
  }
}

class _FakeTwitterClient extends TwitterClient {
  final Map<({String? query, FeedSort? sort, String? cursor}), TweetResponse>
      _responses = {};

  void stub({
    required String? query,
    required FeedSort? sort,
    String? cursor,
    required TweetResponse response,
  }) {
    _responses[(query: query, sort: sort, cursor: cursor)] = response;
  }

  @override
  Future<TweetResponse> fetchTrendingMedia({
    String? cursor,
    String? query,
    FeedSort? sort,
    Set<MediaFilter>? filters,
    int count = 20,
    int cooldownMinutes = 15,
    int? minFaves,
    int timeoutSeconds = 15,
  }) async {
    return _responses[(query: query, sort: sort, cursor: cursor)] ??
        (throw StateError(
          'Missing stub for query=$query sort=$sort cursor=$cursor',
        ));
  }
}
