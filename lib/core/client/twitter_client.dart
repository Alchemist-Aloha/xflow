import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'twitter_account.dart';
import '../models/tweet.dart';
import '../database/entities.dart';
import '../database/repository.dart';
import '../../features/settings/settings_provider.dart';

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

  Future<TweetResponse> fetchUserTweets(String screenName, {String? cursor, FeedSort? sort, Set<MediaFilter>? filters}) async {
    return fetchTrendingMedia(
      query: "from:$screenName",
      cursor: cursor,
      sort: sort,
      filters: filters,
    );
  }

  Future<List<Subscription>> fetchFollowing(String userId, {int maxCount = 1000}) async {
    final allSubs = <Subscription>[];
    String? currentCursor;

    try {
      while (allSubs.length < maxCount) {
        final variables = {
          "userId": userId,
          "count": 100,
          "includePromotedContent": false,
          "withGrokTranslatedBio": false
        };
        if (currentCursor != null) {
          variables["cursor"] = currentCursor;
        }

        final uri = Uri.https('x.com', '/i/api/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following', {
          'variables': jsonEncode(variables),
          'features': jsonEncode(followingFeatures),
        });

        debugPrint('Fetching following with cursor: $currentCursor (Found so far: ${allSubs.length})');
        final response = await TwitterAccount.fetch(uri, cacheDuration: const Duration(hours: 1));
        if (response.statusCode != 200) {
          debugPrint('fetchFollowing Error: ${response.statusCode} ${response.body}');
          break;
        }

        final data = json.decode(response.body);
        final instructions = List.from(data['data']?['user']?['result']?['timeline']?['timeline']?['instructions'] ?? []);
        
        if (instructions.isEmpty) break;

        final addEntries = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries' || e['__typename'] == 'TimelineAddEntries');
        if (addEntries == null) break;

        final entries = List.from(addEntries['entries'] ?? []);
        if (entries.isEmpty) break;

        String? nextCursor;
        int newFound = 0;

        for (final entry in entries) {
          final entryId = entry['entryId'] as String? ?? '';
          if (entryId.startsWith('cursor-bottom-') || entryId.startsWith('sq-cursor-bottom-')) {
            nextCursor = entry['content']?['value'];
            continue;
          }

          final userResult = entry["content"]?["itemContent"]?["user_results"]?["result"];
          if (userResult == null) continue;
          
          final legacy = userResult["core"]?["screen_name"] != null ? userResult["core"] : userResult["legacy"];
          if (legacy == null) continue;

          allSubs.add(Subscription(
            id: userResult["rest_id"],
            screenName: legacy["screen_name"],
            name: legacy["name"] ?? '',
            profileImageUrl: userResult["avatar"]?["image_url"] ?? legacy["profile_image_url_https"],
          ));
          newFound++;
        }

        if (newFound == 0 || nextCursor == null || nextCursor == currentCursor) {
          break;
        }
        currentCursor = nextCursor;
      }
      return allSubs;
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return allSubs;
    }
  }

  Future<TweetResponse> fetchTrendingMedia({String? cursor, String? query, FeedSort? sort, Set<MediaFilter>? filters}) async {
    String finalQuery = query ?? "";
    
    if (filters != null && filters.isNotEmpty) {
      final filterQueries = <String>[];
      for (final f in filters) {
        switch (f) {
          case MediaFilter.video:
            filterQueries.add("filter:videos");
            break;
          case MediaFilter.image:
            filterQueries.add("filter:images");
            break;
          case MediaFilter.gif:
            filterQueries.add("filter:consumer_video");
            break;
          case MediaFilter.text:
            filterQueries.add("-filter:media");
            break;
        }
      }
      final combinedFilter = "(${filterQueries.join(' OR ')})";
      finalQuery = finalQuery.isEmpty ? combinedFilter : "$finalQuery $combinedFilter";
    } else if (query == null) {
      // Default "All" case if no specific query provided
      finalQuery = "filter:media OR -filter:media";
    }

    if (sort == FeedSort.popular) {
      finalQuery += " min_faves:100";
    }

    final variables = {
      "rawQuery": finalQuery,
      "count": "20",
      "product": sort == FeedSort.trending ? "Top" : "Latest",
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
      debugPrint('Fetching media with query: $finalQuery and cursor: $cursor, sort: $sort');
      final response = await TwitterAccount.fetch(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Error status: ${response.statusCode} body: ${response.body}');
        return TweetResponse(tweets: []);
      }

      final result = json.decode(response.body);
      final timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
      if (timeline == null) return TweetResponse(tweets: []);

      final tweetResponse = _parseTweets(timeline);
      
      if (sort == FeedSort.random) {
        tweetResponse.tweets.shuffle();
      } else if (sort == FeedSort.oldest) {
        tweetResponse.tweets.sort((a, b) => a.id.compareTo(b.id));
      }

      return tweetResponse;
    } catch (e) {
      debugPrint('Exception in fetchTrendingMedia: $e');
      return TweetResponse(tweets: []);
    }
  }

  Future<TweetResponse> fetchSubscribedMedia({String? cursor, FeedSort? sort, Set<MediaFilter>? filters}) async {
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
      return fetchTrendingMedia(cursor: cursor, sort: sort, filters: filters);
    }

    final pickedSubs = (subs.toList()..shuffle()).take(20);
    final users = pickedSubs.map((s) => 'from:${s.screenName}').join(' OR ');
    String query = "include:nativeretweets ($users) -filter:replies";
    
    if (sort == FeedSort.popular) {
      query += " min_faves:50";
    }

    final response = await fetchTrendingMedia(cursor: cursor, query: query, sort: sort, filters: filters);
    
    if (cursor == null && response.tweets.length < 5) {
      final trendingResponse = await fetchTrendingMedia(sort: sort, filters: filters);
      final combined = [...response.tweets];
      final seenIds = response.tweets.map((t) => t.id).toSet();
      for (final t in trendingResponse.tweets) {
        if (!seenIds.contains(t.id)) combined.add(t);
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
    
    final addEntries = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries' || e['__typename'] == 'TimelineAddEntries');
    if (addEntries == null) return TweetResponse(tweets: []);

    final entries = List.from(addEntries['entries'] ?? []);
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

      if (tweetResult['rest_id'] == null && tweetResult['tweet'] != null) {
        tweetResult = tweetResult['tweet'];
      }

      var legacy = tweetResult['legacy'];
      if (legacy == null) return;

      var retweetedStatusResult = tweetResult['retweeted_status_result'] ?? legacy['retweeted_status_result'] ?? legacy['repostedStatusResults'];
      if (retweetedStatusResult != null && retweetedStatusResult['result'] != null) {
        var retweetedResult = retweetedStatusResult['result'];
        if (retweetedResult['rest_id'] == null && retweetedResult['tweet'] != null) {
          retweetedResult = retweetedResult['tweet'];
        }
        if (retweetedResult['legacy'] != null) {
          legacy = retweetedResult['legacy'];
          var retweetedCore = retweetedResult['core'] ?? retweetedResult['tweet']?['core'];
          var retweetedUserResults = retweetedCore?['user_results']?['result'];
          var retweetedScreenName = retweetedUserResults?['legacy']?['screen_name'];
          if (retweetedScreenName != null) {
            tweetResult['core'] = retweetedCore;
          }
        }
      }

      final core = tweetResult['core'] ?? tweetResult['tweet']?['core'];
      final userResults = core?['user_results']?['result'];
      final screenName = userResults?['legacy']?['screen_name'] ?? 'Unknown';
      final userAvatarUrl = userResults?['legacy']?['profile_image_url_https'];

      final media = List.from(legacy['entities']?['media'] ?? []);
      final extendedMedia = List.from(legacy['extended_entities']?['media'] ?? []);
      final allMedia = extendedMedia.isNotEmpty ? extendedMedia : media;

      if (allMedia.isEmpty) {
        var noteTweetResult = tweetResult['note_tweet']?['note_tweet_results']?['result'];
        if (noteTweetResult != null) {
          final noteMedia = List.from(noteTweetResult['entity_set']?['media'] ?? []);
          final noteExtendedMedia = List.from(noteTweetResult['extended_entities']?['media'] ?? []);
          allMedia.addAll(noteExtendedMedia.isNotEmpty ? noteExtendedMedia : noteMedia);
        }
      }

      final mediaUrls = <String>[];
      String? thumbnailUrl;
      bool isVideo = false;

      if (allMedia.isNotEmpty && allMedia.first['media_url_https'] != null) {
        thumbnailUrl = allMedia.first['media_url_https'];
      }

      for (final m in allMedia) {
        if (m['type'] == 'video' || m['type'] == 'animated_gif') {
          isVideo = true;
          final variants = List.from(m['video_info']?['variants'] ?? []);
          if (variants.isEmpty) continue;

          var bestVariant = variants
              .where((v) => v['content_type'] == 'video/mp4' && v['url'] != null)
              .toList()
            ..sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
          
          if (bestVariant.isNotEmpty) {
            mediaUrls.add(bestVariant.first['url']);
          } else if (variants.first['url'] != null) {
            mediaUrls.add(variants.first['url']);
          }
        } else if (m['type'] == 'photo') {
          if (m['media_url_https'] != null) {
            mediaUrls.add(m['media_url_https']);
          }
        }
      }

      DateTime? createdAt;
      if (legacy['created_at'] != null) {
        try {
          // X format: "Wed Apr 24 12:34:56 +0000 2024"
          final format = DateFormat("EEE MMM dd HH:mm:ss Z yyyy", "en_US");
          createdAt = format.parse(legacy['created_at']);
        } catch (e) {
          debugPrint('Error parsing date ${legacy['created_at']}: $e');
        }
      }

      tweets.add(Tweet(
        id: tweetResult['rest_id'] ?? tweetResult['tweet']?['rest_id'] ?? entryId,
        text: legacy['full_text'] ?? legacy['text'] ?? '',
        userHandle: '@$screenName',
        userAvatarUrl: userAvatarUrl,
        mediaUrls: mediaUrls,
        thumbnailUrl: thumbnailUrl,
        isVideo: isVideo,
        createdAt: createdAt,
      ));
    } catch (e) {
      debugPrint('Error in parseTweetResult for $entryId: $e');
    }
  }
}
