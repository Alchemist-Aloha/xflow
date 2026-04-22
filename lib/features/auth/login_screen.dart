import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import '../../core/database/entities.dart';
import '../../core/database/repository.dart';
import '../../core/client/twitter_account.dart';

const String bearerToken = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
                 // Try another way to get screen name or just wait
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

              final account = Account(
                id: ct0Cookie.value,
                screenName: screenName,
                authHeader: json.encode(authHeader),
              );

              await Repository.insertAccount(account);
              TwitterAccount.setCurrentAccount(account);

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
