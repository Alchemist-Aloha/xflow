import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class QuerySettingsScreen extends ConsumerWidget {
  const QuerySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Architecture'),
      ),
      body: ListView(
        children: [
          // GROUP 1: GLOBAL STRATEGY
          const _SectionHeader(title: 'Global Discovery Strategy'),
          ListTile(
            title: const Text('Global Fetch Strategy'),
            subtitle:
                Text('Current: ${settings.fetchStrategy.name.toUpperCase()}'),
            trailing: DropdownButton<FeedSort>(
              value: settings.fetchStrategy,
              items: FeedSort.values.map((sort) {
                return DropdownMenuItem(
                  value: sort,
                  child: Text(sort.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null)
                  notifier.updateDiscoveryParam(fetchStrategy: val);
              },
            ),
          ),
          _SliderSetting(
            title: 'Initial Launch Fetch Count',
            subtitle: 'Items to "pepper" into feed on app start',
            value: settings.initialSyncCount.toDouble(),
            min: 1,
            max: 100,
            onChanged: (v) => notifier.updateDiscoveryParam(initialSyncCount: v.toInt()),
          ),
          ListTile(
            title: const Text('Freshness Mix Ratio'),
            subtitle: Text(
                '${(settings.freshMixRatio * 100).toInt()}% Fresh API / ${(100 - settings.freshMixRatio * 100).toInt()}% Local Cache'),
          ),
          Slider(
            value: settings.freshMixRatio,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(settings.freshMixRatio * 100).toInt()}%',
            onChanged: (val) =>
                notifier.updateDiscoveryParam(freshMixRatio: val),
          ),
          _SliderSetting(
            title: 'UI Load Batch Size',
            subtitle: 'Items to fetch when scrolling ends',
            value: settings.loadBatchSize.toDouble(),
            min: 5,
            max: 100,
            onChanged: (v) => notifier.updateLoadBatchSize(v.toInt()),
          ),

          const Divider(),
          // GROUP 2: FEED DIVERSITY (SATURATION)
          const _SectionHeader(title: 'Feed Diversity & Saturation'),
          SwitchListTile(
            title: const Text('Avoid Watched Content'),
            subtitle: const Text('Exclude already played items (Media-Key based)'),
            value: settings.avoidWatchedContent,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(avoidWatchedContent: val),
          ),
          SwitchListTile(
            title: const Text('Unseen Subscription Boost'),
            subtitle: const Text('Prioritize accounts with low play counts'),
            value: settings.unseenSubscriptionBoost,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(unseenSubscriptionBoost: val),
          ),
          _SliderSetting(
            title: 'Account Saturation Threshold',
            subtitle: 'Max items from same user in window',
            value: settings.saturationThreshold.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => notifier.updateDiscoveryParam(saturationThreshold: v.toInt()),
          ),
          _SliderSetting(
            title: 'Media Saturation Threshold',
            subtitle: 'Max copies of same video in window',
            value: settings.mediaSaturationThreshold.toDouble(),
            min: 1,
            max: 5,
            onChanged: (v) => notifier.updateDiscoveryParam(mediaSaturationThreshold: v.toInt()),
          ),
          _SliderSetting(
            title: 'Saturation Window',
            subtitle: 'Number of recent items to check for diversity',
            value: settings.saturationWindow.toDouble(),
            min: 5,
            max: 100,
            onChanged: (v) => notifier.updateDiscoveryParam(saturationWindow: v.toInt()),
          ),
          _SliderSetting(
            title: 'Media Deduplication Window',
            subtitle: 'Sliding window for strict ID/URL deduplication',
            value: settings.mediaDeduplicationWindow.toDouble(),
            min: 10,
            max: 200,
            onChanged: (v) => notifier.updateDiscoveryParam(mediaDeduplicationWindow: v.toInt()),
          ),
          _SliderSetting(
            title: 'Unseen Boost Lookahead',
            subtitle: 'Search depth for finding promoted accounts',
            value: settings.unseenBoostLookahead.toDouble(),
            min: 2,
            max: 50,
            onChanged: (v) => notifier.updateDiscoveryParam(unseenBoostLookahead: v.toInt()),
          ),

          const Divider(),
          // GROUP 3: BACKGROUND SYNC & CACHE
          const _SectionHeader(title: 'Background Sync & Cache'),
          _SliderSetting(
            title: 'Sync Interval (Minutes)',
            value: settings.syncInterval.toDouble(),
            min: 1,
            max: 120,
            onChanged: (v) => notifier.updateSyncInterval(v.toInt()),
          ),
          _SliderSetting(
            title: 'Sync Batch Size',
            subtitle: 'Accounts to crawl per interval',
            value: settings.syncBatchSize.toDouble(),
            min: 1,
            max: 50,
            onChanged: (v) => notifier.updateSyncBatchSize(v.toInt()),
          ),
          _SliderSetting(
            title: 'Account Cooldown',
            subtitle: 'Minutes to wait before re-fetching an account',
            value: settings.cooldownDuration.toDouble(),
            min: 0,
            max: 240,
            onChanged: (v) => notifier.updateCooldownDuration(v.toInt()),
          ),
          _SliderSetting(
            title: 'DB Candidate Multiplier',
            subtitle: 'Local pool size relative to batch size',
            value: settings.dbCandidateMultiplier.toDouble(),
            min: 1,
            max: 20,
            onChanged: (v) => notifier.updateDiscoveryParam(dbCandidateMultiplier: v.toInt()),
          ),
          _SliderSetting(
            title: 'Prune Threshold',
            subtitle: 'Max metadata entries to keep in database',
            value: settings.pruneThreshold.toDouble(),
            min: 1000,
            max: 100000,
            divisions: 99,
            onChanged: (v) => notifier.updatePruneThreshold(v.toInt()),
          ),

          const Divider(),
          // GROUP 4: NETWORK & PERFORMANCE
          const _SectionHeader(title: 'Network & Performance'),
          _SliderSetting(
            title: 'API Timeout (Seconds)',
            value: settings.apiTimeoutSeconds.toDouble(),
            min: 5,
            max: 60,
            onChanged: (v) => notifier.updateDiscoveryParam(apiTimeoutSeconds: v.toInt()),
          ),
          _SliderSetting(
            title: 'API Retry Limit',
            subtitle: 'Max attempts per pagination cycle',
            value: settings.apiRetryLimit.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => notifier.updateDiscoveryParam(apiRetryLimit: v.toInt()),
          ),
          _SliderSetting(
            title: 'Playback Retry Limit',
            subtitle: 'Max attempts to play a failing video',
            value: settings.playbackRetryLimit.toDouble(),
            min: 0,
            max: 5,
            onChanged: (v) => notifier.updateDiscoveryParam(playbackRetryLimit: v.toInt()),
          ),
          _SliderSetting(
            title: 'Auto Skip Delay (Seconds)',
            subtitle: 'Wait time before skipping failed media',
            value: settings.autoSkipDelaySeconds.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => notifier.updateDiscoveryParam(autoSkipDelaySeconds: v.toInt()),
          ),
          _SliderSetting(
            title: 'Lazy Load Threshold',
            subtitle: 'Items remaining before pre-fetching next batch',
            value: settings.lazyLoadThreshold.toDouble(),
            min: 1,
            max: 50,
            onChanged: (v) => notifier.updateDiscoveryParam(lazyLoadThreshold: v.toInt()),
          ),

          const Divider(),
          // GROUP 5: LEGACY CHUNK SEARCH
          const _SectionHeader(title: 'Legacy Search Feed (Chunked)'),
          SwitchListTile(
            title: const Text('Strict Subscriptions Only'),
            subtitle: const Text('Disable trending fallback for empty queries'),
            value: settings.strictSubscriptionsOnly,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(strictSubscriptionsOnly: val),
          ),
          SwitchListTile(
            title: const Text('Include Native Retweets'),
            value: settings.includeNativeRetweets,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(includeNativeRetweets: val),
          ),
          SwitchListTile(
            title: const Text('Use Chunked Subscriptions'),
            subtitle: const Text('Iterate through all subs in blocks'),
            value: settings.useChunkedSubscriptions,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(useChunkedSubscriptions: val),
          ),
          _SliderSetting(
            title: 'Popular Min Faves',
            value: settings.minFavesFilter.toDouble(),
            min: 0,
            max: 1000,
            divisions: 20,
            onChanged: (v) => notifier.updateDiscoveryParam(minFavesFilter: v.toInt()),
          ),
          _SliderSetting(
            title: 'Max Query Length',
            value: settings.maxQueryLength.toDouble(),
            min: 100,
            max: 1000,
            divisions: 18,
            onChanged: (v) => notifier.updateDiscoveryParam(maxQueryLength: v.toInt()),
          ),
          _SliderSetting(
            title: 'Chunk Rotation Limit',
            value: settings.chunkRotationLimit.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => notifier.updateDiscoveryParam(chunkRotationLimit: v.toInt()),
          ),
          _SliderSetting(
            title: 'Min New Tweets Threshold',
            subtitle: 'Required yield before finishing fetch loop',
            value: settings.minNewTweetsThreshold.toDouble(),
            min: 1,
            max: 20,
            onChanged: (v) => notifier.updateDiscoveryParam(minNewTweetsThreshold: v.toInt()),
          ),

          const Divider(),
          // GROUP 6: DIAGNOSTICS
          const _SectionHeader(title: 'Diagnostics'),
          SwitchListTile(
            title: const Text('Show Discovery Debug Info'),
            subtitle: const Text('Overlay source and metadata on feed'),
            value: settings.showDebugInfo,
            onChanged: (val) => notifier.toggleDebugInfo(val),
          ),
          _SliderSetting(
            title: 'Max Saturation Swaps',
            subtitle: 'Safety limit for diversity logic loops',
            value: settings.maxSaturationSwaps.toDouble(),
            min: 100,
            max: 5000,
            divisions: 49,
            onChanged: (v) => notifier.updateDiscoveryParam(maxSaturationSwaps: v.toInt()),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: Text(
            value.toInt().toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? (max - min).toInt(),
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
