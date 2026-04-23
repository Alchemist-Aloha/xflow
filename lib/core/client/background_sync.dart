import 'dart:async';
import 'package:flutter/foundation.dart';
import 'twitter_client.dart';
import '../database/repository.dart';
import '../../features/settings/settings_provider.dart';

class BackgroundSync {
  static Timer? _syncTimer;
  static bool _isSyncing = false;

  static void start(TwitterClient client, SettingsState settings) {
    if (_syncTimer != null) return;
    
    // Initial sync
    _sync(client, settings);
    
    _syncTimer = Timer.periodic(
      Duration(minutes: settings.syncInterval), 
      (_) => _sync(client, settings)
    );
    
    // Prune DB 1 minute after start
    Future.delayed(const Duration(minutes: 1), () {
      Repository.pruneCachedMedia(threshold: settings.pruneThreshold);
    });
  }

  static void restart(TwitterClient client, SettingsState settings) {
    stop();
    start(client, settings);
  }

  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _sync(TwitterClient client, SettingsState settings) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final subs = await Repository.getSubscriptions();
      if (subs.isEmpty) return;

      // Pick a random subset from settings
      subs.shuffle();
      final targets = subs.take(settings.syncBatchSize);
      final usersQuery = targets.map((s) => 'from:${s.screenName}').join(' OR ');
      final query = "include:nativeretweets ($usersQuery) -filter:replies";

      // Fetch latest
      final response = await client.fetchTrendingMedia(
        query: query,
        count: settings.loadBatchSize,
        cooldownMinutes: settings.cooldownDuration,
      );
      
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
