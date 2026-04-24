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
          const _SectionHeader(title: 'Cache Logic'),
          SwitchListTile(
            title: const Text('Avoid Watched Content'),
            subtitle:
                const Text('Exclude already played items from candidate pool'),
            value: settings.avoidWatchedContent,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(avoidWatchedContent: val),
          ),
          SwitchListTile(
            title: const Text('Unseen Subscription Boost'),
            subtitle: const Text(
                'Prioritize items from accounts you haven\'t watched much'),
            value: settings.unseenSubscriptionBoost,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(unseenSubscriptionBoost: val),
          ),
          const Divider(),
          const _SectionHeader(title: 'Discovery Mix'),
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
          ListTile(
            title: const Text('Account Saturation Window'),
            subtitle: Text('Check for duplicates within the last ${settings.saturationWindow} items'),
          ),
          Slider(
            value: settings.saturationWindow.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: '${settings.saturationWindow}',
            onChanged: (val) =>
                notifier.updateDiscoveryParam(saturationWindow: val.toInt()),
          ),
          ListTile(
            title: const Text('Unseen Boost Lookahead'),
            subtitle: Text('Try to promote accounts by looking ahead ${settings.unseenBoostLookahead} items'),
          ),
          Slider(
            value: settings.unseenBoostLookahead.toDouble(),
            min: 2,
            max: 20,
            divisions: 18,
            label: '${settings.unseenBoostLookahead}',
            onChanged: (val) =>
                notifier.updateDiscoveryParam(unseenBoostLookahead: val.toInt()),
          ),
          const Divider(),
          const _SectionHeader(title: 'Diversity & Fetch'),
          ListTile(
            title: const Text('Account Saturation Threshold'),
            subtitle: Text(
                'Max ${settings.saturationThreshold} items from same user in window'),
          ),
          Slider(
            value: settings.saturationThreshold.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '${settings.saturationThreshold}',
            onChanged: (val) =>
                notifier.updateDiscoveryParam(saturationThreshold: val.toInt()),
          ),
          ListTile(
            title: const Text('Popular Strategy Min Faves'),
            subtitle: const Text('Threshold for "Popular" fetch strategy'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.minFavesFilter.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null)
                    notifier.updateDiscoveryParam(minFavesFilter: v);
                },
              ),
            ),
          ),
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
          ListTile(
            title: const Text('Initial Launch Fetch Count'),
            subtitle:
                const Text('Number of items to "pepper" into feed on start'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.initialSyncCount.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final count = int.tryParse(val);
                  if (count != null)
                    notifier.updateDiscoveryParam(initialSyncCount: count);
                },
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Strict Subscriptions Only'),
            subtitle: const Text(
                'Do not inject global trending when subscription query is sparse'),
            value: settings.strictSubscriptionsOnly,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(strictSubscriptionsOnly: val),
          ),
          SwitchListTile(
            title: const Text('Include Native Retweets'),
            subtitle: const Text(
                'Allow retweets from followed accounts in subscription feed query'),
            value: settings.includeNativeRetweets,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(includeNativeRetweets: val),
          ),
          SwitchListTile(
            title: const Text('Use Chunked Subscription Queries'),
            subtitle: const Text(
                'Build query chunks from all subscriptions instead of random sampling'),
            value: settings.useChunkedSubscriptions,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(useChunkedSubscriptions: val),
          ),
          SwitchListTile(
            title: const Text('Show Discovery Debug Info'),
            subtitle: const Text(
                'Show media type, source (API/Cache), and metadata on the feed'),
            value: settings.showDebugInfo,
            onChanged: (val) => notifier.toggleDebugInfo(val),
          ),
          const Divider(),
          const _SectionHeader(title: 'Sync Architecture'),

          ListTile(
            title: const Text('Background Sync Interval'),
            subtitle: Text('${settings.syncInterval} minutes'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.syncInterval.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null) notifier.updateSyncInterval(v);
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('Background Sync Batch Size'),
            subtitle: const Text('Number of accounts to sync per interval'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.syncBatchSize.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null) notifier.updateSyncBatchSize(v);
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('UI Load Batch Size'),
            subtitle: const Text('Number of items to fetch when scrolling'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.loadBatchSize.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null) notifier.updateLoadBatchSize(v);
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('Account Cooldown'),
            subtitle:
                const Text('Minutes to wait before re-fetching an account'),
            trailing: SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: settings.cooldownDuration.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null) notifier.updateCooldownDuration(v);
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('Prune Threshold'),
            subtitle: const Text('Max metadata entries to keep in DB'),
            trailing: SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: settings.pruneThreshold.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (val) {
                  final v = int.tryParse(val);
                  if (v != null) notifier.updatePruneThreshold(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
