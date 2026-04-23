import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'twitter_account.dart';
import '../models/tweet.dart';
import '../database/entities.dart';
import '../database/repository.dart';

class TwitterClient {
  static const String graphqlSearchTimelineUriPath = '/graphql/nK1dw4oV3k4w5TdtcAdSww/SearchTimeline';
  static const String graphqlFollowingUriPath = '/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following';
  static const String graphqlUserByScreenNameUriPath = '/graphql/oUZZZ8Oddwxs8Cd3iW3UEA/UserByScreenName';

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

  static const Map<String, dynamic> followingFeatures = {
    "rweb_video_screen_enabled": false,
    "payments_enabled": false,
    "profile_label_improvements_pcf_label_in_post_enabled": true,
    "responsive_web_profile_redirect_enabled": false,
    "rweb_tipjar_consumption_enabled": true,
    "verified_phone_label_enabled": false,
    "creator_subscriptions_tweet_preview_api_enabled": true,
    "responsive_web_graphql_timeline_navigation_enabled": true,
    "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
    "premium_content_api_read_enabled": false,
    "communities_web_enable_tweet_community_results_fetch": true,
    "c9s_tweet_anatomy_moderator_badge_enabled": true,
    "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
    "responsive_web_grok_analyze_post_followups_enabled": true,
    "responsive_web_jetfuel_frame": true,
    "responsive_web_grok_share_attachment_enabled": true,
    "articles_preview_enabled": true,
    "responsive_web_edit_tweet_api_enabled": true,
    "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
    "view_counts_everywhere_api_enabled": true,
    "longform_notetweets_consumption_enabled": true,
    "responsive_web_twitter_article_tweet_consumption_enabled": true,
    "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
    "standardized_nudges_misinfo": true,
    "longform_notetweets_rich_text_read_enabled": true,
    "longform_notetweets_inline_media_enabled": true,
    "responsive_web_grok_image_annotation_enabled": true,
    "responsive_web_grok_imagine_annotation_enabled": true,
    "responsive_web_grok_community_note_auto_translation_is_enabled": false,
    "responsive_web_enhance_cards_enabled": false
  };

  Future<Subscription?> fetchUserByScreenName(String screenName) async {
    if (screenName.startsWith('@')) screenName = screenName.substring(1);
    
    final uri = Uri.https('x.com', '/i/api/graphql/oUZZZ8Oddwxs8Cd3iW3UEA/UserByScreenName', {
      'variables': jsonEncode({
        'screen_name': screenName,
        'withHighlightedLabel': true,
        'withSafetyModeUserFields': true,
        'withSuperFollowsUserFields': true
      }),
      'features': jsonEncode(defaultFeatures)
    });

    try {
      final response = await TwitterAccount.fetch(uri);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final userRes = data['data']?['user']?['result'];
      if (userRes == null) return null;

      final legacy = userRes['legacy'];
      return Subscription(
        id: userRes['rest_id'],
        screenName: legacy?['screen_name'] ?? screenName,
        name: legacy?['name'] ?? screenName,
        profileImageUrl: legacy?['profile_image_url_https'],
      );
    } catch (e) {
      debugPrint('Error fetching user by screen name: $e');
      return null;
    }
  }

  Future<List<Subscription>> fetchFollowing(String userId) async {
    final variables = {
      "userId": userId,
      "count": 100,
      "includePromotedContent": false,
      "withGrokTranslatedBio": false
    };

    final uri = Uri.https('x.com', '/i/api/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(followingFeatures),
    });

    try {
      final response = await TwitterAccount.fetch(uri);
      if (response.statusCode != 200) {
        debugPrint('fetchFollowing Error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = json.decode(response.body);
      final instructions = List.from(data['data']?['user']?['result']?['timeline']?['timeline']?['instructions'] ?? []);
      
      final subs = <Subscription>[];
      for (final instruction in instructions) {
        if (instruction["type"] != "TimelineAddEntries" || instruction["entries"] == null) continue;
        
        for (final entry in instruction["entries"]) {
          final userResult = entry["content"]?["itemContent"]?["user_results"]?["result"];
          if (userResult == null) continue;
          
          final legacy = userResult["core"]?["screen_name"] != null ? userResult["core"] : userResult["legacy"];
          if (legacy == null) continue;

          subs.add(Subscription(
            id: userResult["rest_id"],
            screenName: legacy["screen_name"],
            name: legacy["name"] ?? '',
            profileImageUrl: userResult["avatar"]?["image_url"] ?? legacy["profile_image_url_https"],
          ));
        }
      }
      return subs;
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return [];
    }
  }

  Future<List<Tweet>> fetchTrendingMedia({String? cursor, String? query}) async {
    final variables = {
      "rawQuery": query ?? "filter:media",
      "count": "20",
      "product": "Latest",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    if (cursor != null) variables['cursor'] = cursor;

    final uri = Uri.https('api.x.com', graphqlSearchTimelineUriPath, {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures),
    });

    try {
      final response = await TwitterAccount.fetch(uri);
      if (response.statusCode != 200) return [];

      final result = json.decode(response.body);
      final timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
      if (timeline == null) return [];

      return _parseTweets(timeline);
    } catch (e) {
      debugPrint('Exception in fetchTrendingMedia: $e');
      return [];
    }
  }

  Future<List<Tweet>> fetchSubscribedMedia({String? cursor}) async {
    var subs = await Repository.getSubscriptions();
    
    if (subs.isEmpty) {
      final currentAccount = TwitterAccount.currentAccount;
      if (currentAccount != null && currentAccount.restId.isNotEmpty) {
        subs = await fetchFollowing(currentAccount.restId);
        if (subs.isNotEmpty) {
          await Repository.insertSubscriptions(subs);
        }
      }
    }

    if (subs.isEmpty) {
      return fetchTrendingMedia(cursor: cursor);
    }

    // Pick a subset of users to query
    final pickedSubs = (subs.toList()..shuffle()).take(10);
    final users = pickedSubs.map((s) => 'from:${s.screenName}').join(' OR ');
    final query = "($users) filter:media";

    return fetchTrendingMedia(cursor: cursor, query: query);
  }

  List<Tweet> _parseTweets(Map<String, dynamic> timeline) {
    final tweets = <Tweet>[];
    final instructions = List.from(timeline['timeline']?['instructions'] ?? []);
    if (instructions.isEmpty) return [];

    final addEntries = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
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

        final core = tweetResult['core'] ?? tweetResult['tweet']?['core'];
        final userResults = core?['user_results']?['result'];
        final screenName = userResults?['legacy']?['screen_name'] ?? 'Unknown';

        final media = List.from(legacy['entities']?['media'] ?? []);
        if (media.isEmpty) continue;

        final mediaUrls = <String>[];
        bool isVideo = false;

        for (final m in media) {
          if (m['type'] == 'video' || m['type'] == 'animated_gif') {
            isVideo = true;
            final variants = List.from(m['video_info']?['variants'] ?? []);
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
