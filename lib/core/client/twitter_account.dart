import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ffcache/ffcache.dart';
import 'x_api_constants.dart';
import 'transaction_id_service.dart';
import '../database/entities.dart';
import '../database/repository.dart';
import '../utils/app_logger.dart';

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

  static String compactForLog(Object? value, {int? maxLength}) {
    if (value == null) return 'null';
    final flattened = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (maxLength == null || flattened.length <= maxLength) {
      return flattened;
    }
    return '${flattened.substring(0, maxLength).trimRight()}...';
  }

  static Object? _decodeLogValue(String value) {
    final decoded = Uri.decodeQueryComponent(value);
    try {
      return jsonDecode(decoded);
    } catch (_) {
      return decoded;
    }
  }

  static String formatUriForLog(Uri uri) {
    if (uri.query.isEmpty) return uri.path;
    final params = <String, Object?>{};
    for (final entry in uri.queryParameters.entries) {
      params[entry.key] = _decodeLogValue(entry.value);
    }
    return '${uri.path} params=${compactForLog(params)}';
  }

  static String formatTransactionIdForLog(String? transactionId) {
    if (transactionId == null || transactionId.isEmpty) {
      return 'missing';
    }
    return compactForLog(transactionId);
  }

  static String _summarizeRequest(Uri uri, String method, Object? body) {
    final query = uri.query.isEmpty ? '' : ' ${formatUriForLog(uri)}';
    final bodySummary = body == null ? '' : ' body=${compactForLog(body)}';
    return '$method$query$bodySummary';
  }

  static Future<http.Response> fetch(Uri uri,
      {String method = 'GET',
      Object? body,
      Map<String, String>? headers,
      Duration? cacheDuration}) async {
    final requestSummary = _summarizeRequest(uri, method, body);
    final cacheKey = _getCacheKey(uri);
    if (method == 'GET' && cacheDuration != null) {
      final cachedBody = await _cache.getString(cacheKey);
      if (cachedBody != null) {
        AppLogger.log(
            'HTTP cache hit: $requestSummary bytes=${cachedBody.length}');
        return http.Response(cachedBody, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      }
      AppLogger.log(
          'HTTP cache miss: $requestSummary ttl=${cacheDuration.inMinutes}m');
    }

    if (_currentAccount == null) {
      await init();
    }

    final combinedHeaders = <String, String>{
      'accept': '*/*',
      'accept-language': 'en-US,en;q=0.9',
      'authorization': xBearerToken,
      'cache-control': 'no-cache',
      'content-type': 'application/json',
      'pragma': 'no-cache',
      'referer': 'https://x.com',
      'origin': 'https://x.com',
      'user-agent': xMobileUserAgent,
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
    String? transactionId;
    String txIdStatus = 'missing';
    try {
      transactionId = await TransactionIdService.instance.generateForRequest(
        uri.path,
        method: method,
      );
      if (transactionId != null) {
        combinedHeaders['x-client-transaction-id'] = transactionId;
        txIdStatus = 'local:${formatTransactionIdForLog(transactionId)}';
      } else {
        final transactionUri = Uri.http('x-client-transaction-id-generator.xyz',
            '/generate-x-client-transaction-id', {'path': uri.path});
        final transactionResponse =
            await http.get(transactionUri).timeout(const Duration(seconds: 2));
        if (transactionResponse.statusCode == 200) {
          transactionId =
              jsonDecode(transactionResponse.body)['x-client-transaction-id'];
          if (transactionId != null) {
            combinedHeaders['x-client-transaction-id'] = transactionId;
            txIdStatus = 'fallback:${formatTransactionIdForLog(transactionId)}';
          } else {
            txIdStatus = 'missing:null-response-field';
          }
        } else {
          txIdStatus =
              'missing:generator-status-${transactionResponse.statusCode}';
        }
      }
    } catch (e) {
      txIdStatus = 'missing:error:${e.runtimeType}';
      debugPrint('Error generating x-client-transaction-id: $e');
    }

    AppLogger.log(
        'HTTP request start: $requestSummary account=${_currentAccount?.screenName ?? 'none'} txId=$txIdStatus');
    final stopwatch = Stopwatch()..start();
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
    stopwatch.stop();
    AppLogger.log(
        'HTTP request end: $requestSummary status=${response.statusCode} elapsedMs=${stopwatch.elapsedMilliseconds} bytes=${response.bodyBytes.length}');

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
