import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'twitter_account.dart';
import '../models/tweet.dart';

class TwitterClient {
  static const String graphqlSearchTimelineUriPath = '/graphql/nK1dw4oV3k4w5TdtcAdSww/SearchTimeline';
  
  static const Map<String, dynamic> defaultFeatures = {
    'responsive_web_graphql_exclude_directive_enabled': true,
    'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
    'responsive_web_graphql_timeline_navigation_enabled': true,
    'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
    'view_counts_everywhere_api_enabled': true,
    'longform_notetweets_consumption_enabled': true,
    'responsive_web_twitter_article_tweet_consumption_enabled': true,
    'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
    'standardized_nudges_misinfo': true,
  };

  Future<List<Tweet>> fetchTrendingMedia({String? cursor}) async {
    final variables = {
      "rawQuery": "filter:media", // Search for media
      "count": "20",
      "product": "Latest",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    final uri = Uri.https('api.x.com', graphqlSearchTimelineUriPath, {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures),
    });

    try {
      final response = await TwitterAccount.fetch(uri);
      if (response.statusCode != 200) {
        debugPrint('Error fetching trending media: ${response.statusCode} - ${response.body}');
        return [];
      }

      final result = json.decode(response.body);
      final timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
      if (timeline == null) return [];

      return _parseTweets(timeline);
    } catch (e) {
      debugPrint('Exception in fetchTrendingMedia: $e');
      return [];
    }
  }

  List<Tweet> _parseTweets(Map<String, dynamic> timeline) {
    final tweets = <Tweet>[];
    final instructions = List.from(timeline['timeline']?['instructions'] ?? []);
    if (instructions.isEmpty) return [];

    final addEntries = instructions.firstWhere(
      (e) => e['type'] == 'TimelineAddEntries',
      orElse: () => null,
    );

    if (addEntries == null) return [];

    final entries = List.from(addEntries['entries'] ?? []);
    for (final entry in entries) {
      final entryId = entry['entryId'] as String;
      if (!entryId.startsWith('tweet-')) continue;

      try {
        final tweetResult = entry['content']?['itemContent']?['tweet_results']?['result'];
        if (tweetResult == null) continue;

        final legacy = tweetResult['legacy'] ?? tweetResult['tweet']?['legacy'];
        if (legacy == null) continue;

        final userResults = tweetResult['core']?['user_results']?['result'] ?? tweetResult['tweet']?['core']?['user_results']?['result'];
        final screenName = userResults?['legacy']?['screen_name'] ?? 'Unknown';

        final media = List.from(legacy['entities']?['media'] ?? []);
        if (media.isEmpty) continue;

        final mediaUrls = <String>[];
        bool isVideo = false;

        for (final m in media) {
          if (m['type'] == 'video' || m['type'] == 'animated_gif') {
            isVideo = true;
            final variants = List.from(m['video_info']?['variants'] ?? []);
            // Find highest quality mp4
            final bestVariant = variants
                .where((v) => v['content_type'] == 'video/mp4')
                .toList()
              ..sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
            
            if (bestVariant.isNotEmpty) {
              mediaUrls.add(bestVariant.first['url']);
            }
          } else {
            mediaUrls.add(m['media_url_https']);
          }
        }

        if (mediaUrls.isNotEmpty) {
          tweets.add(Tweet(
            id: tweetResult['rest_id'] ?? tweetResult['tweet']?['rest_id'],
            text: legacy['full_text'] ?? '',
            userHandle: '@$screenName',
            mediaUrls: mediaUrls,
            isVideo: isVideo,
          ));
        }
      } catch (e) {
        debugPrint('Error parsing tweet entry $entryId: $e');
      }
    }

    return tweets;
  }
}
