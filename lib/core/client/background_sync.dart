import 'dart:async';
import 'package:flutter/foundation.dart';
import 'twitter_client.dart';
import '../database/repository.dart';

class BackgroundSync {
  static Timer? _syncTimer;
  static bool _isSyncing = false;

  static void start(TwitterClient client) {
    if (_syncTimer != null) return;
    
    // Check every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _sync(client));
    
    // Prune DB 1 minute after start
    Future.delayed(const Duration(minutes: 1), () {
      Repository.pruneCachedMedia();
    });
  }

  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _sync(TwitterClient client) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final subs = await Repository.getSubscriptions();
      if (subs.isEmpty) return;

      // Pick a random subset of 10 subs to avoid huge queries
      subs.shuffle();
      final targets = subs.take(10);
      final usersQuery = targets.map((s) => 'from:${s.screenName}').join(' OR ');
      final query = "include:nativeretweets ($usersQuery) -filter:replies";

      // Fetch latest
      final response = await client.fetchTrendingMedia(query: query);
      
      if (response.tweets.isNotEmpty) {
        await Repository.insertCachedMedia(response.tweets);
      }
    } catch (e) {
      debugPrint('Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
