import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ffcache/ffcache.dart';
import '../database/entities.dart';
import '../database/repository.dart';

class TwitterAccount {
  static Account? _currentAccount;
  static final FFCache _cache = FFCache();

  static Account? get currentAccount => _currentAccount;

  static Future<void> init() async {
    final accounts = await Repository.getAccounts();
    if (accounts.isNotEmpty) {
      _currentAccount = accounts.first;
    }
  }

  static bool hasAccountAvailable() {
    return _currentAccount != null;
  }

  static String _getCacheKey(Uri uri) {
    return md5.convert(utf8.encode(uri.toString())).toString();
  }

  static Future<http.Response> fetch(Uri uri,
      {String method = 'GET',
      Object? body,
      Map<String, String>? headers,
      Duration? cacheDuration}) async {
    final cacheKey = _getCacheKey(uri);
    if (method == 'GET' && cacheDuration != null) {
      final cachedBody = await _cache.getString(cacheKey);
      if (cachedBody != null) {
        return http.Response(cachedBody, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      }
    }

    if (_currentAccount == null) {
      await init();
    }

    final combinedHeaders = <String, String>{
      'accept': '*/*',
      'accept-language': 'en-US,en;q=0.9',
      'authorization':
          'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
      'cache-control': 'no-cache',
      'content-type': 'application/json',
      'pragma': 'no-cache',
      'referer': 'https://x.com',
      'origin': 'https://x.com',
      'user-agent':
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.3',
      'x-twitter-active-user': 'yes',
      'x-twitter-client-language': 'en',
      'x-twitter-auth-type': 'OAuth2Session',
      ...?headers,
    };

    if (_currentAccount != null) {
      final authHeaders =
          Map<String, String>.from(json.decode(_currentAccount!.authHeader));
      combinedHeaders.addAll(authHeaders);
    }

    // Try to get x-client-transaction-id
    try {
      final transactionUri = Uri.http('x-client-transaction-id-generator.xyz',
          '/generate-x-client-transaction-id', {'path': uri.path});
      final transactionResponse =
          await http.get(transactionUri).timeout(const Duration(seconds: 2));
      if (transactionResponse.statusCode == 200) {
        final transactionId =
            jsonDecode(transactionResponse.body)['x-client-transaction-id'];
        if (transactionId != null) {
          combinedHeaders['x-client-transaction-id'] = transactionId;
        }
      }
    } catch (e) {
      debugPrint('Error generating x-client-transaction-id: $e');
    }

    final http.Response response;
    if (method == 'POST') {
      response = await http
          .post(uri, headers: combinedHeaders, body: body)
          .timeout(const Duration(seconds: 15));
    } else {
      response = await http
          .get(uri, headers: combinedHeaders)
          .timeout(const Duration(seconds: 15));
    }

    if (response.statusCode == 200) {
      // Force UTF-8 decoding for the body string to avoid mangling and caching issues
      final decodedBody = utf8.decode(response.bodyBytes);
      if (method == 'GET' && cacheDuration != null) {
        await _cache.setStringWithTimeout(cacheKey, decodedBody, cacheDuration);
      }
      return http.Response(decodedBody, 200, headers: {
        ...response.headers,
        'content-type': 'application/json; charset=utf-8',
      });
    }
    return response;
  }

  static void setCurrentAccount(Account account) {
    _currentAccount = account;
  }

  static Future<void> logout() async {
    final db = await Repository.database;
    await db.delete(tableAccounts);
    _currentAccount = null;
  }
}
