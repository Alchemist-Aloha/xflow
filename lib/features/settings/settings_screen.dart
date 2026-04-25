import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/client/account_provider.dart';
import '../../core/database/repository.dart';
import '../../core/utils/media_cache_manager.dart';
import '../feed/feed_provider.dart';
import '../subscriptions/subscription_import_screen.dart';
import 'log_viewer_screen.dart';
import 'debug_timeline_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _metadataCount = 0;
  double _cacheSizeMB = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await Repository.getCachedMediaCount();
    final sizeBytes = await CustomMediaCacheManager.getCacheSize();
    if (mounted) {
      setState(() {
        _metadataCount = count;
        _cacheSizeMB = sizeBytes / (1024 * 1024);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _SettingsGroup(
            title: 'Experience',
            children: [
              _SettingsTile(
                icon: Icons.play_circle_outline,
                title: 'Playback & Feed',
                subtitle: 'Sorting, autoplay, and delivery mix',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const PlaybackSettingsPage())),
              ),
              _SettingsTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Discovery & Diversity',
                subtitle: 'Algorithm tuning and content variety',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const DiscoverySettingsPage())),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Data & Storage',
            children: [
              _SettingsTile(
                icon: Icons.sync_outlined,
                title: 'Background Fetch',
                subtitle: 'Sync intervals and background crawling',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const SyncSettingsPage())),
              ),
              _SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Storage & Cache',
                subtitle:
                    '${_cacheSizeMB.toStringAsFixed(1)} MB used • $_metadataCount items',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => StorageSettingsPage(
                              metadataCount: _metadataCount,
                              cacheSizeMB: _cacheSizeMB,
                              onRefresh: _loadStats,
                            ))),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Content Sources',
            children: [
              _SettingsTile(
                icon: Icons.people_outline,
                title: 'Subscriptions',
                subtitle: 'Import, export, or clear follow list',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const SubscriptionSettingsPage())),
              ),
              _SettingsTile(
                icon: Icons.search_outlined,
                title: 'Legacy Fetch',
                subtitle: 'Advanced subscription crawling parameters',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const SearchSettingsPage())),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'System',
            children: [
              _SettingsTile(
                icon: Icons.network_check_outlined,
                title: 'Network & Performance',
                subtitle: 'Timeouts, retries, and loading thresholds',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const NetworkSettingsPage())),
              ),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Diagnostics & Logs',
                subtitle: 'Debug tools and algorithm safety caps',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const DiagnosticSettingsPage())),
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                titleColor: Colors.redAccent,
                onTap: () async {
                  await ref.read(accountProvider.notifier).logout();
                  ref.invalidate(feedNotifierProvider);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon,
          color: titleColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// --- SUB PAGES ---

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  String _getFeedSortLabel(FeedSort sort) {
    switch (sort) {
      case FeedSort.latest:
        return 'Subs: Latest';
      case FeedSort.popular:
        return 'Subs: Popular';
      case FeedSort.trending:
        return 'Subs: Trending';
      case FeedSort.algorithmic:
        return 'For You (X)';
      case FeedSort.chronological:
        return 'Following (X)';
      case FeedSort.videomixer:
        return 'Video Mixer (X)';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Playback & Feed')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Content Strategy'),
            subtitle:
                Text('Current: ${_getFeedSortLabel(settings.fetchStrategy)}'),
            trailing: DropdownButton<FeedSort>(
              value: settings.fetchStrategy,
              items: FeedSort.values
                  .map((sort) => DropdownMenuItem(
                        value: sort,
                        child: Text(_getFeedSortLabel(sort)),
                      ))
                  .toList(),
              onChanged: (val) => val != null
                  ? notifier.updateDiscoveryParam(fetchStrategy: val)
                  : null,
            ),
          ),
          SwitchListTile(
            title: const Text('Autoplay'),
            subtitle: const Text('Automatically play videos when visible'),
            value: settings.autoplay,
            onChanged: (v) => notifier.toggleAutoplay(v),
          ),
          ListTile(
            title: const Text('After Video Ends'),
            subtitle:
                Text('Action: ${settings.videoEndAction.name.toUpperCase()}'),
            trailing: DropdownButton<VideoEndAction>(
              value: settings.videoEndAction,
              items: VideoEndAction.values
                  .map((action) => DropdownMenuItem(
                        value: action,
                        child: Text(action.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (val) => val != null
                  ? notifier.updateDiscoveryParam(videoEndAction: val)
                  : null,
            ),
          ),
          _SliderSetting(
            title: 'Video Load Retries',
            subtitle: 'Attempts to play a video if it fails to load',
            value: settings.playbackRetryLimit.toDouble(),
            min: 0,
            max: 5,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(playbackRetryLimit: v.toInt()),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Content Filters',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: MediaFilter.values
                  .map((f) => FilterChip(
                        label: Text(f.name.toUpperCase()),
                        selected: settings.filters.contains(f),
                        onSelected: (_) => notifier.toggleFilter(f),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          _SliderSetting(
            title: 'Initial Feed Size',
            subtitle: 'Videos to load immediately when the app starts',
            value: settings.initialSyncCount.toDouble(),
            min: 1,
            max: 100,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(initialSyncCount: v.toInt()),
          ),
          _SliderSetting(
            title: 'Scroll Batch Size',
            subtitle: 'New videos to load when reaching the end',
            value: settings.loadBatchSize.toDouble(),
            min: 5,
            max: 100,
            onChanged: (v) => notifier.updateLoadBatchSize(v.toInt()),
          ),
          ListTile(
            title: const Text('New vs. Cached Mix'),
            subtitle: Text(
                '${(settings.freshMixRatio * 100).toInt()}% Fresh / ${(100 - settings.freshMixRatio * 100).toInt()}% Saved'),
          ),
          Slider(
            value: settings.freshMixRatio,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(freshMixRatio: val),
          ),
        ],
      ),
    );
  }
}

class DiscoverySettingsPage extends ConsumerWidget {
  const DiscoverySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Discovery & Diversity')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Avoid Seen Content'),
            subtitle: const Text('Hide videos you have already watched'),
            value: settings.avoidWatchedContent,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(avoidWatchedContent: val),
          ),
          SwitchListTile(
            title: const Text('Unseen Creator Boost'),
            subtitle:
                const Text('Show more content from creators you rarely see'),
            value: settings.unseenSubscriptionBoost,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(unseenSubscriptionBoost: val),
          ),
          const Divider(),
          _SliderSetting(
            title: 'Creator Diversity',
            subtitle: 'Max videos from same creator in a row',
            value: settings.saturationThreshold.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(saturationThreshold: v.toInt()),
          ),
          _SliderSetting(
            title: 'Video Diversity',
            subtitle: 'Max copies of same video in window',
            value: settings.mediaSaturationThreshold.toDouble(),
            min: 1,
            max: 5,
            onChanged: (v) => notifier.updateDiscoveryParam(
                mediaSaturationThreshold: v.toInt()),
          ),
          _SliderSetting(
            title: 'Diversity Window',
            subtitle: 'How far back the algorithm looks to ensure variety',
            value: settings.saturationWindow.toDouble(),
            min: 5,
            max: 100,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(saturationWindow: v.toInt()),
          ),
          _SliderSetting(
            title: 'Strict Deduplication',
            subtitle: 'Lookback for exact media-key matches',
            value: settings.mediaDeduplicationWindow.toDouble(),
            min: 10,
            max: 200,
            onChanged: (v) => notifier.updateDiscoveryParam(
                mediaDeduplicationWindow: v.toInt()),
          ),
          _SliderSetting(
            title: 'Discovery Range',
            subtitle: 'Search depth for finding creators to boost',
            value: settings.unseenBoostLookahead.toDouble(),
            min: 2,
            max: 50,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(unseenBoostLookahead: v.toInt()),
          ),
          _SliderSetting(
            title: 'Candidate Pool Size',
            subtitle: 'Local search space for building a diverse feed',
            value: settings.dbCandidateMultiplier.toDouble(),
            min: 1,
            max: 20,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(dbCandidateMultiplier: v.toInt()),
          ),
        ],
      ),
    );
  }
}

class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Background Fetch')),
      body: ListView(
        children: [
          _SliderSetting(
            title: 'Refresh Frequency (Mins)',
            subtitle: 'How often the app checks for new videos',
            value: settings.syncInterval.toDouble(),
            min: 1,
            max: 120,
            onChanged: (v) => notifier.updateSyncInterval(v.toInt()),
          ),
          _SliderSetting(
            title: 'Refresh Intensity',
            subtitle: 'Accounts to check per refresh session',
            value: settings.syncBatchSize.toDouble(),
            min: 1,
            max: 50,
            onChanged: (v) => notifier.updateSyncBatchSize(v.toInt()),
          ),
          _SliderSetting(
            title: 'Account Cool-off',
            subtitle: 'Wait time before checking the same account again',
            value: settings.cooldownDuration.toDouble(),
            min: 0,
            max: 240,
            onChanged: (v) => notifier.updateCooldownDuration(v.toInt()),
          ),
        ],
      ),
    );
  }
}

class StorageSettingsPage extends ConsumerWidget {
  final int metadataCount;
  final double cacheSizeMB;
  final VoidCallback onRefresh;

  const StorageSettingsPage({
    super.key,
    required this.metadataCount,
    required this.cacheSizeMB,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Cache')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Local Media Cache'),
            subtitle: Text(
                '${cacheSizeMB.toStringAsFixed(1)} MB used / ${settings.mediaCacheSizeMB} MB limit'),
          ),
          Slider(
            value: settings.mediaCacheSizeMB.toDouble(),
            min: 100,
            max: 2000,
            divisions: 19,
            label: '${settings.mediaCacheSizeMB} MB',
            onChanged: (v) => notifier.updateMediaCacheSize(v.round()),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('Clear Media Cache',
                style: TextStyle(color: Colors.orange)),
            onTap: () async {
              await CustomMediaCacheManager.clearCache();
              onRefresh();
            },
          ),
          const Divider(),
          _SliderSetting(
            title: 'Database Record Limit',
            subtitle: 'Max video metadata entries to keep in storage',
            value: settings.pruneThreshold.toDouble(),
            min: 1000,
            max: 100000,
            divisions: 99,
            onChanged: (v) => notifier.updatePruneThreshold(v.toInt()),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Purge Seen Metadata',
                style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Delete database records for watched videos'),
            onTap: () async {
              await Repository.purgeSeenMetadata();
              onRefresh();
            },
          ),
        ],
      ),
    );
  }
}

class SubscriptionSettingsPage extends ConsumerWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Import Subscriptions'),
            subtitle: const Text('Sync follows from an existing X account'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (c) => const SubscriptionImportScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.orange),
            title: const Text('Clear All Subscriptions',
                style: TextStyle(color: Colors.orange)),
            onTap: () async {
              await Repository.clearSubscriptions();
              ref.invalidate(feedNotifierProvider);
              if (context.mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Cleared')));
            },
          ),
        ],
      ),
    );
  }
}

class NetworkSettingsPage extends ConsumerWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Network & Performance')),
      body: ListView(
        children: [
          _SliderSetting(
            title: 'Network Timeout (Secs)',
            value: settings.apiTimeoutSeconds.toDouble(),
            min: 5,
            max: 60,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(apiTimeoutSeconds: v.toInt()),
          ),
          _SliderSetting(
            title: 'API Request Size',
            subtitle: 'Target items to request from X per call',
            value: settings.timelineBatchSize.toDouble(),
            min: 5,
            max: 200,
            onChanged: (v) => notifier.updateTimelineBatchSize(v.toInt()),
          ),
          _SliderSetting(
            title: 'Network Retry Limit',
            subtitle: 'Attempts per page if a request fails',
            value: settings.apiRetryLimit.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(apiRetryLimit: v.toInt()),
          ),
          _SliderSetting(
            title: 'Pre-load Threshold',
            subtitle: 'Fetch next batch when this many remain in feed',
            value: settings.lazyLoadThreshold.toDouble(),
            min: 1,
            max: 50,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(lazyLoadThreshold: v.toInt()),
          ),
          _SliderSetting(
            title: 'Failure Skip Delay',
            subtitle: 'Seconds to wait before skipping broken media',
            value: settings.autoSkipDelaySeconds.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(autoSkipDelaySeconds: v.toInt()),
          ),
        ],
      ),
    );
  }
}

class SearchSettingsPage extends ConsumerWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Legacy Fetch')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Strict Subscriptions'),
            subtitle: const Text('Disable trending fallback for empty queries'),
            value: settings.strictSubscriptionsOnly,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(strictSubscriptionsOnly: val),
          ),
          SwitchListTile(
            title: const Text('Include Retweets'),
            value: settings.includeNativeRetweets,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(includeNativeRetweets: val),
          ),
          SwitchListTile(
            title: const Text('Chunked Crawling'),
            subtitle: const Text('Iterate through follow list in blocks'),
            value: settings.useChunkedSubscriptions,
            onChanged: (val) =>
                notifier.updateDiscoveryParam(useChunkedSubscriptions: val),
          ),
          _SliderSetting(
            title: 'Chunk Size',
            subtitle: 'Accounts to query per search block',
            value: settings.searchBatchSize.toDouble(),
            min: 1,
            max: 50,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(searchBatchSize: v.toInt()),
          ),
          _SliderSetting(
            title: 'Minimum Favorites Filter',
            value: settings.minFavesFilter.toDouble(),
            min: 0,
            max: 1000,
            divisions: 20,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(minFavesFilter: v.toInt()),
          ),
          _SliderSetting(
            title: 'Max Search Query Length',
            value: settings.maxQueryLength.toDouble(),
            min: 100,
            max: 1000,
            divisions: 18,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(maxQueryLength: v.toInt()),
          ),
          _SliderSetting(
            title: 'Rotation Cycle',
            subtitle: 'Blocks to skip before repeating creators',
            value: settings.chunkRotationLimit.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(chunkRotationLimit: v.toInt()),
          ),
          _SliderSetting(
            title: 'Minimum Yield',
            subtitle: 'New items required before finishing loop',
            value: settings.minNewTweetsThreshold.toDouble(),
            min: 1,
            max: 20,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(minNewTweetsThreshold: v.toInt()),
          ),
        ],
      ),
    );
  }
}

class DiagnosticSettingsPage extends ConsumerWidget {
  const DiagnosticSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Overlay Source Info'),
            subtitle: const Text('Display discovery metadata on top of videos'),
            value: settings.showDebugInfo,
            onChanged: (v) => notifier.toggleDebugInfo(v),
          ),
          _SliderSetting(
            title: 'Algorithm Safety Cap',
            subtitle: 'Max calculations for diversity logic',
            value: settings.maxSaturationSwaps.toDouble(),
            min: 100,
            max: 5000,
            divisions: 49,
            onChanged: (v) =>
                notifier.updateDiscoveryParam(maxSaturationSwaps: v.toInt()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('View App Logs'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (c) => const LogViewerScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Debug Timeline'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (c) => const DebugTimelineScreen())),
          ),
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
