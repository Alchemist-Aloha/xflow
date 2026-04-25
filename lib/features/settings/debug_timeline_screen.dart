import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_twitter_api/twitter_api.dart' as official;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/client/twitter_account.dart';

class DebugTimelineScreen extends StatefulWidget {
  const DebugTimelineScreen({super.key});

  @override
  State<DebugTimelineScreen> createState() => _DebugTimelineScreenState();
}

class _DebugTimelineScreenState extends State<DebugTimelineScreen> {
  final _consumerKeyController = TextEditingController();
  final _consumerSecretController = TextEditingController();
  final _tokenController = TextEditingController();
  final _secretController = TextEditingController();
  final _gqlBatchController = TextEditingController(text: '20');
  
  List<String> _results = [];
  String _rawJson = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _consumerKeyController.text = prefs.getString('debug_ck') ?? '';
      _consumerSecretController.text = prefs.getString('debug_cs') ?? '';
      _tokenController.text = prefs.getString('debug_t') ?? '';
      _secretController.text = prefs.getString('debug_s') ?? '';
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debug_ck', _consumerKeyController.text);
    await prefs.setString('debug_cs', _consumerSecretController.text);
    await prefs.setString('debug_t', _tokenController.text);
    await prefs.setString('debug_s', _secretController.text);
  }

  Future<void> _fetchOfficialTimeline() async {
    await _saveKeys();
    setState(() {
      _isLoading = true;
      _results = [];
      _rawJson = '';
    });

    try {
      // Use official alias to avoid conflict with local TwitterClient
      final twitterApi = official.TwitterApi(
        client: official.TwitterClient(
          consumerKey: _consumerKeyController.text,
          consumerSecret: _consumerSecretController.text,
          token: _tokenController.text,
          secret: _secretController.text,
        ),
      );

      final homeTimeline = await twitterApi.timelineService.homeTimeline(
        count: 200,
      );

      setState(() {
        _results = homeTimeline.map((tweet) => '[Official] ${tweet.user?.screenName}: ${tweet.fullText ?? tweet.text}').toList();
        if (_results.isEmpty) {
          _results = ['Timeline returned 0 items.'];
        }
      });
    } catch (e) {
      setState(() => _results = ['Error: $e']);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGraphQL(String type) async {
    setState(() {
      _isLoading = true;
      _results = [];
      _rawJson = '';
    });

    try {
      String path = '';
      final int batchSize = int.tryParse(_gqlBatchController.text) ?? 20;
      Map<String, dynamic> variables = {
        "count": batchSize,
        "includePromotedContent": true,
        "latestControlAvailable": true,
        "requestContext": "launch",
      };

      if (type == 'MediaTabVideoMixer') {
        path = '/graphql/rAqW5uh6Unfi46lidxFwzA/MediaTabVideoMixer';
      } else if (type == 'HomeTimeline') {
        path = '/graphql/Yf4WJo0fW46TnqrHUw_1Ow/HomeTimeline';
      } else if (type == 'HomeLatestTimeline') {
        path = '/graphql/hlno2aLQsxiQlOrK-a2V-w/HomeLatestTimeline';
      }

      final features = {
        "rweb_video_screen_enabled": false,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "unified_cards_ad_metadata_container_dynamic_card_content_query_enabled": false,
        "viewer_is_blue_verified": true,
        "interactive_text_enabled": true,
        "responsive_web_text_conversations_enabled": false,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_from_backend": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": true,
        "responsive_web_enhance_cards_enabled": false
      };

      final uri = Uri.https('x.com', '/i/api$path', {
        'variables': jsonEncode(variables),
        'features': jsonEncode(features),
      });

      final response = await TwitterAccount.fetch(uri);
      
      setState(() {
        _rawJson = response.body;
        
        // Very basic extraction for debug view
        _results = ['Status: ${response.statusCode}', 'Path: $path'];
        
        // Try to find any text fields to show it's working
        final bodyStr = response.body;
        if (bodyStr.contains('full_text')) {
           _results.add('Found "full_text" in response. API seems to work!');
        } else if (bodyStr.contains('errors')) {
           _results.add('API returned errors. Check session/cookies.');
        } else {
           _results.add('Response received but no tweets identified in simple scan.');
        }
      });

    } catch (e) {
      setState(() => _results = ['Exception: $e']);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Timeline')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Official API (OAuth 1.0a)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _consumerKeyController, decoration: const InputDecoration(labelText: 'CK'), style: const TextStyle(fontSize: 10))),
                const SizedBox(width: 4),
                Expanded(child: TextField(controller: _tokenController, decoration: const InputDecoration(labelText: 'T'), style: const TextStyle(fontSize: 10))),
              ],
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchOfficialTimeline,
              child: const Text('Fetch Official', style: TextStyle(fontSize: 12)),
            ),
            const Divider(),
            const Text('Internal GraphQL (Current Session)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Batch Size: ', style: TextStyle(fontSize: 12)),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _gqlBatchController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _fetchGraphQL('MediaTabVideoMixer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('Video Mixer', style: TextStyle(fontSize: 11)),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _fetchGraphQL('HomeTimeline'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('Home (For You)', style: TextStyle(fontSize: 11)),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _fetchGraphQL('HomeLatestTimeline'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: const Text('Home (Following)', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const Divider(),
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._results.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(r, style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
                    )),
                    if (_rawJson.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RAW JSON (First 1000 chars):',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 10)),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _rawJson));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Full JSON copied to clipboard'),
                                    duration: Duration(seconds: 1)),
                              );
                            },
                            tooltip: 'Copy Full JSON',
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Text(
                          _rawJson.length > 1000 ? _rawJson.substring(0, 1000) : _rawJson,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
