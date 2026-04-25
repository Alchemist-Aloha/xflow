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
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _SectionHeader(title: 'Feed Mix & Delivery'),
          _SettingsCard(children: [
            ListTile(
              title: const Text('Content Sorting'),
              subtitle: Text('Current: ${settings.fetchStrategy.name.toUpperCase()}'),
              trailing: DropdownButton<FeedSort>(
                value: settings.fetchStrategy,
                items: FeedSort.values.map((sort) => DropdownMenuItem(
                  value: sort,
                  child: Text(sort.name.toUpperCase()),
                )).toList(),
                onChanged: (val) => val != null ? notifier.updateDiscoveryParam(fetchStrategy: val) : null,
              ),
            ),
            _SliderSetting(
              title: 'API Request Size',
              subtitle: 'Items to request from X per call',
              value: settings.timelineBatchSize.toDouble(),
              min: 5, max: 200,
              onChanged: (v) => notifier.updateTimelineBatchSize(v.toInt()),
            ),
            _SliderSetting(
              title: 'Scroll Batch Size',
              subtitle: 'Items to fetch when scrolling ends',
              value: settings.loadBatchSize.toDouble(),
              min: 5, max: 100,
              onChanged: (v) => notifier.updateLoadBatchSize(v.toInt()),
            ),
          ]),

          _SectionHeader(title: 'Variety Engine'),
          _SettingsCard(children: [
            _SliderSetting(
              title: 'Video Diversity',
              subtitle: 'Max copies of same video in window',
              value: settings.mediaSaturationThreshold.toDouble(),
              min: 1, max: 5,
              onChanged: (v) => notifier.updateDiscoveryParam(mediaSaturationThreshold: v.toInt()),
            ),
            _SliderSetting(
              title: 'Strict Deduplication',
              subtitle: 'Lookback for exact media-key matches',
              value: settings.mediaDeduplicationWindow.toDouble(),
              min: 10, max: 200,
              onChanged: (v) => notifier.updateDiscoveryParam(mediaDeduplicationWindow: v.toInt()),
            ),
          ]),

          _SectionHeader(title: 'Candidate Management'),
          _SettingsCard(children: [
            _SliderSetting(
              title: 'Candidate Pool Size',
              subtitle: 'Local search space for feed building',
              value: settings.dbCandidateMultiplier.toDouble(),
              min: 1, max: 20,
              onChanged: (v) => notifier.updateDiscoveryParam(dbCandidateMultiplier: v.toInt()),
            ),
          ]),

          _SectionHeader(title: 'Advanced Search Tuning'),
          _SettingsCard(children: [
            _SliderSetting(
              title: 'Max Search Length',
              subtitle: 'Limit for complex query strings',
              value: settings.maxQueryLength.toDouble(),
              min: 100, max: 1000, divisions: 18,
              onChanged: (v) => notifier.updateDiscoveryParam(maxQueryLength: v.toInt()),
            ),
            _SliderSetting(
              title: 'Rotation Cycle',
              subtitle: 'Blocks to skip before repeating creators',
              value: settings.chunkRotationLimit.toDouble(),
              min: 1, max: 10,
              onChanged: (v) => notifier.updateDiscoveryParam(chunkRotationLimit: v.toInt()),
            ),
            _SliderSetting(
              title: 'Minimum Yield',
              subtitle: 'Items required before finishing fetch loop',
              value: settings.minNewTweetsThreshold.toDouble(),
              min: 1, max: 20,
              onChanged: (v) => notifier.updateDiscoveryParam(minNewTweetsThreshold: v.toInt()),
            ),
          ]),

          _SectionHeader(title: 'Optimization'),
          _SettingsCard(children: [
            _SliderSetting(
              title: 'Algorithm Safety Cap',
              subtitle: 'Max calculations for diversity logic',
              value: settings.maxSaturationSwaps.toDouble(),
              min: 100, max: 5000, divisions: 49,
              onChanged: (v) => notifier.updateDiscoveryParam(maxSaturationSwaps: v.toInt()),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
