import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/entities.dart';
import '../database/repository.dart';

class TwitterAccount {
  static Account? _currentAccount;

  static Future<void> init() async {
    final accounts = await Repository.getAccounts();
    if (accounts.isNotEmpty) {
      _currentAccount = accounts.first;
    }
  }

  static bool hasAccountAvailable() {
    return _currentAccount != null;
  }

  static Future<http.Response> fetch(Uri uri, {Map<String, String>? headers}) async {
    if (_currentAccount == null) {
      await init();
    }

    final combinedHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Content-Type': 'application/json',
      ...?headers,
    };

    if (_currentAccount != null) {
      final authHeaders = Map<String, String>.from(json.decode(_currentAccount!.authHeader));
      combinedHeaders.addAll(authHeaders);
    }

    return http.get(uri, headers: combinedHeaders);
  }
  
  static void setCurrentAccount(Account account) {
    _currentAccount = account;
  }
}
