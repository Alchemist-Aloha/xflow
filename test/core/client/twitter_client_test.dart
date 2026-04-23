import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/twitter_client.dart';

void main() {
  group('TwitterClient _parseTweets', () {
    late TwitterClient client;

    setUp(() {
      client = TwitterClient();
    });

    test('handles empty timeline correctly', () {
      final result = client.parseTweetsForTesting({});
      expect(result.tweets, isEmpty);
      expect(result.cursorTop, isNull);
      expect(result.cursorBottom, isNull);
    });

    test('handles timeline with empty instructions', () {
      final result = client.parseTweetsForTesting({
        'timeline': {
          'instructions': []
        }
      });
      expect(result.tweets, isEmpty);
    });

    test('handles missing TimelineAddEntries instruction', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {'type': 'TimelineClearCache'}
        ]
      });
      expect(result.tweets, isEmpty);
    });

    test('parses cursorTop from cursor-top- entryId using value', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'cursor-top-123',
                'content': {
                  'value': 'top_cursor_value'
                }
              }
            ]
          }
        ]
      });
      expect(result.cursorTop, 'top_cursor_value');
    });

    test('parses cursorTop from sq-cursor-top- entryId using cursorType fallback', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'sq-cursor-top-456',
                'content': {
                  'cursorType': 'top_cursor_fallback'
                }
              }
            ]
          }
        ]
      });
      expect(result.cursorTop, 'top_cursor_fallback');
    });

    test('parses cursorBottom from cursor-bottom- entryId using value', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'cursor-bottom-123',
                'content': {
                  'value': 'bottom_cursor_value'
                }
              }
            ]
          }
        ]
      });
      expect(result.cursorBottom, 'bottom_cursor_value');
    });

    test('parses cursorBottom from sq-cursor-bottom- entryId using cursorType fallback', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'sq-cursor-bottom-456',
                'content': {
                  'cursorType': 'bottom_cursor_fallback'
                }
              }
            ]
          }
        ]
      });
      expect(result.cursorBottom, 'bottom_cursor_fallback');
    });

    test('safely ignores entries without content', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'tweet-123',
                // No content key
              }
            ]
          }
        ]
      });
      expect(result.tweets, isEmpty);
    });

    test('parses TimelineTimelineItem successfully', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'tweet-123',
                'content': {
                  'entryType': 'TimelineTimelineItem',
                  'itemContent': {
                    'tweet_results': {
                      'result': {
                        'rest_id': 'tweet_id_1',
                        'legacy': {
                          'full_text': 'Hello world',
                          'created_at': 'Wed Oct 10 20:19:24 +0000 2018',
                        },
                        'core': {
                          'user_results': {
                            'result': {
                              'legacy': {
                                'screen_name': 'testuser'
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            ]
          }
        ]
      });
      expect(result.tweets, isNotEmpty);
      expect(result.tweets.first.id, 'tweet_id_1');
      expect(result.tweets.first.text, 'Hello world');
      expect(result.tweets.first.userHandle, '@testuser');
    });

    test('parses TimelineTimelineModule containing items', () {
      final result = client.parseTweetsForTesting({
        'instructions': [
          {
            'type': 'TimelineAddEntries',
            'entries': [
              {
                'entryId': 'module-123',
                'content': {
                  'entryType': 'TimelineTimelineModule',
                  'items': [
                    {
                      'item': {
                        'itemContent': {
                          'tweet_results': {
                            'result': {
                              'rest_id': 'module_tweet_1',
                              'legacy': {
                                'full_text': 'Module tweet',
                                'created_at': 'Wed Oct 10 20:19:24 +0000 2018',
                              },
                              'core': {
                                'user_results': {
                                  'result': {
                                    'legacy': {
                                      'screen_name': 'moduleuser'
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        ]
      });
      expect(result.tweets, isNotEmpty);
      expect(result.tweets.first.id, 'module_tweet_1');
      expect(result.tweets.first.text, 'Module tweet');
      expect(result.tweets.first.userHandle, '@moduleuser');
    });
  });
}
