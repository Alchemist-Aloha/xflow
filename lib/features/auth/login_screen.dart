import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/account_provider.dart';
import '../../core/database/entities.dart';
import '../../core/database/repository.dart';
import '../../core/client/twitter_client.dart';

const String bearerToken = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  final _cookieManager = WebviewCookieManager();
  bool _userFound = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.3')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url == "https://x.com/home") {
              if (_userFound) return;
              
              String screenName = (await _controller.runJavaScriptReturningResult(
                "document.documentElement.outerHTML.match(/\"screen_name\":\"([^\"]+)\"/)?.[1] ?? '';"
              )).toString();
              
              if (screenName == '' || screenName == 'null') {
                 return;
              }
              screenName = screenName.replaceAll('"', '');
              _userFound = true;

              final cookies = await _cookieManager.getCookies("https://x.com/home");
              final ct0Cookie = cookies.firstWhere((c) => c.name == 'ct0', orElse: () => throw Exception('ct0 not found'));
              
              final authHeader = {
                "Cookie": cookies
                  .where((c) => ['guest_id', 'gt', 'att', 'auth_token', 'ct0'].contains(c.name))
                  .map((c) => '${c.name}=${c.value}')
                  .join(";"),
                "authorization": bearerToken,
                "x-csrf-token": ct0Cookie.value,
              };

              // Fetch rest_id using screenName
              final profileUri = Uri.https('x.com', '/i/api/graphql/oUZZZ8Oddwxs8Cd3iW3UEA/UserByScreenName', {
                'variables': jsonEncode({
                  'screen_name': screenName,
                  'withHighlightedLabel': true,
                  'withSafetyModeUserFields': true,
                  'withSuperFollowsUserFields': true
                }),
                'features': jsonEncode(TwitterClient.defaultFeatures)
              });

              final profileRes = await http.get(profileUri, headers: {
                ...authHeader,
                'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.3',
                'Content-Type': 'application/json',
              });

              String restId = '';
              if (profileRes.statusCode == 200) {
                final profileData = json.decode(profileRes.body);
                final userResult = profileData['data']?['user']?['result'];
                if (userResult != null) {
                  restId = userResult['rest_id'] ?? '';
                }
              }

              final account = Account(
                id: ct0Cookie.value,
                screenName: screenName,
                restId: restId,
                authHeader: json.encode(authHeader),
              );

              await Repository.insertAccount(account);
              ref.read(accountProvider.notifier).login(account);

              if (mounted) {
                Navigator.pop(context, true);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse("https://x.com/i/flow/login"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to X')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
