import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:xflow/core/client/twitter_client.dart';
import 'package:xflow/core/models/tweet.dart';
import 'package:xflow/features/feed/feed_provider.dart';
import 'package:xflow/features/feed/hashtag_provider.dart';
import 'package:xflow/features/settings/settings_provider.dart';

import 'tiktok_feed_screen_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HashtagMediaNotifier', () {
    late MockTwitterClient mockClient;

    setUp(() {
      mockClient = MockTwitterClient();
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

      when(mockClient.fetchTrendingMedia(
        cursor: anyNamed('cursor'),
        query: '#nature (filter:images OR filter:videos)',
        count: anyNamed('count'),
        sort: FeedSort.trending,
        filters: anyNamed('filters'),
        cooldownMinutes: anyNamed('cooldownMinutes'),
        minFaves: anyNamed('minFaves'),
        timeoutSeconds: anyNamed('timeoutSeconds'),
      )).thenAnswer((_) async => TweetResponse(tweets: []));
      when(mockClient.fetchTrendingMedia(
        cursor: anyNamed('cursor'),
        query: '#nature (filter:images OR filter:videos)',
        count: anyNamed('count'),
        sort: FeedSort.latest,
        filters: anyNamed('filters'),
        cooldownMinutes: anyNamed('cooldownMinutes'),
        minFaves: anyNamed('minFaves'),
        timeoutSeconds: anyNamed('timeoutSeconds'),
      )).thenAnswer((_) async => TweetResponse(
            tweets: [latestTweet],
            cursorBottom: 'latest_cursor',
          ));

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
