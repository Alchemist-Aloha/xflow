import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'twitter_account.dart';
import '../models/tweet.dart';
import '../database/entities.dart';
import '../database/repository.dart';

class TweetResponse {
  final List<Tweet> tweets;
  final String? cursorTop;
  final String? cursorBottom;

  TweetResponse({required this.tweets, this.cursorTop, this.cursorBottom});
}

class TwitterClient {
  static const String graphqlSearchTimelineUriPath = '/graphql/nK1dw4oV3k4w5TdtcAdSww/SearchTimeline';
  static const String graphqlFollowingUriPath = '/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following';
  static const String graphqlUserByScreenNameUriPath = '/graphql/oUZZZ8Oddwxs8Cd3iW3UEA/UserByScreenName';

  static const Map<String, dynamic> defaultFeatures = {
    'android_ad_formats_media_component_render_overlay_enabled': false,
    'android_graphql_skip_api_media_color_palette': false,
    'android_professional_link_spotlight_display_enabled': false,
    'articles_api_enabled': false,
    'articles_preview_enabled': true,
    'blue_business_profile_image_shape_enabled': false,
    'c9s_tweet_anatomy_moderator_badge_enabled': true,
    'commerce_android_shop_module_enabled': false,
    'communities_web_enable_tweet_community_results_fetch': true,
    'creator_subscriptions_quote_tweet_preview_enabled': false,
    'creator_subscriptions_subscription_count_enabled': false,
    'creator_subscriptions_tweet_preview_api_enabled': true,
    'freedom_of_speech_not_reach_fetch_enabled': true,
    'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
    'grok_android_analyze_trend_fetch_enabled': false,
    'grok_translations_community_note_auto_translation_is_enabled': false,
    'grok_translations_community_note_translation_is_enabled': false,
    'grok_translations_post_auto_translation_is_enabled': false,
    'grok_translations_timeline_user_bio_auto_translation_is_enabled': false,
    'hidden_profile_likes_enabled': false,
    'highlights_tweets_tab_ui_enabled': false,
    'immersive_video_status_linkable_timestamps': false,
    'interactive_text_enabled': false,
    'longform_notetweets_consumption_enabled': true,
    'longform_notetweets_inline_media_enabled': true,
    'longform_notetweets_richtext_consumption_enabled': true,
    'longform_notetweets_rich_text_read_enabled': true,
    'mobile_app_spotlight_module_enabled': false,
    'payments_enabled': false,
    'post_ctas_fetch_enabled': true,
    'premium_content_api_read_enabled': false,
    'profile_label_improvements_pcf_label_in_post_enabled': true,
    'profile_label_improvements_pcf_label_in_profile_enabled': false,
    'responsive_web_edit_tweet_api_enabled': true,
    'responsive_web_enhance_cards_enabled': false,
    'responsive_web_graphql_exclude_directive_enabled': true,
    'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
    'responsive_web_graphql_timeline_navigation_enabled': true,
    'responsive_web_grok_analysis_button_from_backend': true,
    'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
    'responsive_web_grok_analyze_post_followups_enabled': true,
    'responsive_web_grok_annotations_enabled': true,
    'responsive_web_grok_image_annotation_enabled': true,
    'responsive_web_grok_imagine_annotation_enabled': true,
    'responsive_web_grok_share_attachment_enabled': true,
    'responsive_web_grok_show_grok_translated_post': false,
    'responsive_web_jetfuel_frame': true,
    'responsive_web_media_download_video_enabled': false,
    'responsive_web_profile_redirect_enabled': false,
    'responsive_web_text_conversations_enabled': false,
    'responsive_web_twitter_article_notes_tab_enabled': false,
    'responsive_web_twitter_article_tweet_consumption_enabled': true,
    'responsive_web_twitter_blue_verified_badge_is_enabled': true,
    'rweb_lists_timeline_redesign_enabled': true,
    'rweb_tipjar_consumption_enabled': true,
    'rweb_video_screen_enabled': false,
    'rweb_video_timestamps_enabled': false,
    'spaces_2022_h2_clipping': true,
    'spaces_2022_h2_spaces_communities': true,
    'standardized_nudges_misinfo': true,
    'subscriptions_feature_can_gift_premium': false,
    'subscriptions_verification_info_enabled': true,
    'subscriptions_verification_info_is_identity_verified_enabled': false,
    'subscriptions_verification_info_reason_enabled': true,
    'subscriptions_verification_info_verified_since_enabled': true,
    'super_follow_badge_privacy_enabled': false,
    'super_follow_exclusive_tweet_notifications_enabled': false,
    'super_follow_tweet_api_enabled': false,
    'super_follow_user_api_enabled': false,
    'tweet_awards_web_tipping_enabled': false,
    'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
    'tweetypie_unmention_optimization_enabled': false,
    'unified_cards_ad_metadata_container_dynamic_card_content_query_enabled': false,
    'unified_cards_destination_url_params_enabled': false,
    'verified_phone_label_enabled': false,
    'vibe_api_enabled': false,
    'view_counts_everywhere_api_enabled': true,
    'hidden_profile_subscriptions_enabled': false,
  };

  static const Map<String, dynamic> followingFeatures = defaultFeatures;

  Future<Subscription?> fetchProfile(String screenName) async {
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
        description: legacy?['description'],
        followersCount: legacy?['followers_count'],
        followingCount: legacy?['friends_count'],
      );
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<TweetResponse> fetchUserTweets(String screenName, {String? cursor}) async {
    return fetchTrendingMedia(query: "from:$screenName filter:media", cursor: cursor);
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

  Future<TweetResponse> fetchTrendingMedia({String? cursor, String? query}) async {
    final variables = {
      "rawQuery": query ?? "filter:media",
      "count": "20",
      "product": "Latest",
      "querySource": "typed_query",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    if (cursor != null) variables['cursor'] = cursor;

    final uri = Uri.https('x.com', '/i/api$graphqlSearchTimelineUriPath', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures),
    });

    try {
      debugPrint('Fetching media with query: ${query ?? "filter:media"} and cursor: $cursor');
      final response = await TwitterAccount.fetch(uri);
      debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('Error body: ${response.body}');
        return TweetResponse(tweets: []);
      }

      final result = json.decode(response.body);
      final timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
      if (timeline == null) {
        debugPrint('Timeline is null in response. Full result keys: ${result?.keys}');
        return TweetResponse(tweets: []);
      }

      return _parseTweets(timeline);
    } catch (e) {
      debugPrint('Exception in fetchTrendingMedia: $e');
      return TweetResponse(tweets: []);
    }
  }

  Future<TweetResponse> fetchSubscribedMedia({String? cursor}) async {
    var subs = await Repository.getSubscriptions();
    debugPrint('Found ${subs.length} local subscriptions');
    
    if (subs.isEmpty) {
      final currentAccount = TwitterAccount.currentAccount;
      if (currentAccount != null && currentAccount.restId.isNotEmpty) {
        debugPrint('Fetching following for ${currentAccount.screenName}');
        subs = await fetchFollowing(currentAccount.restId);
        if (subs.isNotEmpty) {
          await Repository.insertSubscriptions(subs);
          debugPrint('Inserted ${subs.length} subscriptions into DB');
        }
      }
    }

    if (subs.isEmpty) {
      debugPrint('No subscriptions found, falling back to trending');
      return fetchTrendingMedia(cursor: cursor);
    }

    // Pick a subset of users to query
    final pickedSubs = (subs.toList()..shuffle()).take(20);
    final users = pickedSubs.map((s) => 'from:${s.screenName}').join(' OR ');
    // Added -filter:replies to get more original posts/retweets and less noise
    final query = "include:nativeretweets ($users) filter:media -filter:replies";

    debugPrint('Searching media from ${pickedSubs.length} users with query: $query');
    final response = await fetchTrendingMedia(cursor: cursor, query: query);
    
    // If we're at the first page and results are very few, mix in some trending
    if (cursor == null && response.tweets.length < 5) {
      debugPrint('Few subscribed media found (${response.tweets.length}), fetching some trending media too...');
      final trendingResponse = await fetchTrendingMedia();
      
      // Combine and deduplicate
      final combined = [...response.tweets];
      final seenIds = response.tweets.map((t) => t.id).toSet();
      for (final t in trendingResponse.tweets) {
        if (!seenIds.contains(t.id)) {
          combined.add(t);
        }
      }
      return TweetResponse(
        tweets: combined,
        cursorTop: response.cursorTop,
        cursorBottom: response.cursorBottom,
      );
    }
    
    return response;
  }

  TweetResponse _parseTweets(Map<String, dynamic> timeline) {
    final tweets = <Tweet>[];
    final instructions = List.from(timeline['timeline']?['instructions'] ?? []);
    debugPrint('Instructions count: ${instructions.length}');
    if (instructions.isEmpty) {
      debugPrint('No instructions found in timeline. Keys: ${timeline.keys}');
      return TweetResponse(tweets: []);
    }

    final addEntries = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries' || e['__typename'] == 'TimelineAddEntries');
    if (addEntries == null) {
      debugPrint('No TimelineAddEntries found. Instruction types: ${instructions.map((e) => e['type'] ?? e['__typename']).toList()}');
      return TweetResponse(tweets: []);
    }

    final entries = List.from(addEntries['entries'] ?? []);
    debugPrint('Total entries in TimelineAddEntries: ${entries.length}');
    
    String? cursorTop;
    String? cursorBottom;

    for (final entry in entries) {
      final entryId = entry['entryId'] as String? ?? '';
      
      if (entryId.startsWith('cursor-top-') || entryId.startsWith('sq-cursor-top-')) {
        cursorTop = entry['content']?['value'];
      } else if (entryId.startsWith('cursor-bottom-') || entryId.startsWith('sq-cursor-bottom-')) {
        cursorBottom = entry['content']?['value'];
      }

      try {
        final content = entry['content'];
        if (content == null) continue;

        if (content['entryType'] == 'TimelineTimelineModule') {
          final items = List.from(content['items'] ?? []);
          for (final item in items) {
            final itemEntry = item['item'];
            if (itemEntry != null) {
              parseTweetResult(itemEntry, entryId, tweets);
            }
          }
          continue;
        }

        if (content['entryType'] == 'TimelineTimelineItem') {
          parseTweetResult(content, entryId, tweets);
        }
      } catch (e) {
        debugPrint('Error parsing entry $entryId: $e');
      }
    }
    
    debugPrint('Parsed ${tweets.length} tweets');
    return TweetResponse(
      tweets: tweets,
      cursorTop: cursorTop,
      cursorBottom: cursorBottom,
    );
  }

  void parseTweetResult(Map<String, dynamic> itemContent, String entryId, List<Tweet> tweets) {
    try {
      var tweetResult = itemContent['itemContent']?['tweet_results']?['result'] ?? itemContent['tweet_results']?['result'];
      if (tweetResult == null) return;

      if (tweetResult['__typename'] == 'TweetWithVisibilityResults') {
        tweetResult = tweetResult['tweet_results']?['result'];
      }
      if (tweetResult == null) return;

      // Handle nested tweet field if rest_id is missing
      if (tweetResult['rest_id'] == null && tweetResult['tweet'] != null) {
        tweetResult = tweetResult['tweet'];
      }

      var legacy = tweetResult['legacy'];
      if (legacy == null) return;

      // Handle retweets
      var retweetedStatusResult = tweetResult['retweeted_status_result'] ?? legacy['retweeted_status_result'] ?? legacy['repostedStatusResults'];
      if (retweetedStatusResult != null && retweetedStatusResult['result'] != null) {
        var retweetedResult = retweetedStatusResult['result'];
        if (retweetedResult['rest_id'] == null && retweetedResult['tweet'] != null) {
          retweetedResult = retweetedResult['tweet'];
        }
        if (retweetedResult['legacy'] != null) {
          legacy = retweetedResult['legacy'];
          // Use the retweeted tweet's user for the handle
          var retweetedCore = retweetedResult['core'] ?? retweetedResult['tweet']?['core'];
          var retweetedUserResults = retweetedCore?['user_results']?['result'];
          var retweetedScreenName = retweetedUserResults?['legacy']?['screen_name'];
          if (retweetedScreenName != null) {
            tweetResult['core'] = retweetedCore; // Override core for screenName extraction later
          }
        }
      }

      final core = tweetResult['core'] ?? tweetResult['tweet']?['core'];
      final userResults = core?['user_results']?['result'];
      final screenName = userResults?['legacy']?['screen_name'] ?? 'Unknown';

      // Media can be in entities or extended_entities
      // extended_entities usually has the video_info we need
      final media = List.from(legacy['entities']?['media'] ?? []);
      final extendedMedia = List.from(legacy['extended_entities']?['media'] ?? []);
      final allMedia = extendedMedia.isNotEmpty ? extendedMedia : media;

      if (allMedia.isEmpty) {
        // Sometimes media is in the note_tweet
        var noteTweetResult = tweetResult['note_tweet']?['note_tweet_results']?['result'];
        if (noteTweetResult != null) {
          final noteMedia = List.from(noteTweetResult['entity_set']?['media'] ?? []);
          final noteExtendedMedia = List.from(noteTweetResult['extended_entities']?['media'] ?? []);
          allMedia.addAll(noteExtendedMedia.isNotEmpty ? noteExtendedMedia : noteMedia);
        }
      }

      if (allMedia.isEmpty) return;

      final mediaUrls = <String>[];
      bool isVideo = false;

      for (final m in allMedia) {
        if (m['type'] == 'video' || m['type'] == 'animated_gif') {
          isVideo = true;
          final variants = List.from(m['video_info']?['variants'] ?? []);
          if (variants.isEmpty) continue;

          // Find the best quality MP4
          var bestVariant = variants
              .where((v) => v['content_type'] == 'video/mp4' && v['url'] != null)
              .toList()
            ..sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
          
          if (bestVariant.isNotEmpty) {
            mediaUrls.add(bestVariant.first['url']);
          } else if (variants.first['url'] != null) {
            // Fallback to first variant if no MP4 found
            mediaUrls.add(variants.first['url']);
          }
        } else if (m['type'] == 'photo') {
          if (m['media_url_https'] != null) {
            mediaUrls.add(m['media_url_https']);
          }
        }
      }

      if (mediaUrls.isNotEmpty) {
        tweets.add(Tweet(
          id: tweetResult['rest_id'] ?? tweetResult['tweet']?['rest_id'] ?? entryId,
          text: legacy['full_text'] ?? legacy['text'] ?? '',
          userHandle: '@$screenName',
          mediaUrls: mediaUrls,
          isVideo: isVideo,
        ));
      }
    } catch (e) {
      debugPrint('Error in parseTweetResult for $entryId: $e');
    }
  }
}
