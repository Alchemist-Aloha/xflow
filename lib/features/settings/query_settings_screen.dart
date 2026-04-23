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
      appBar: AppBar(title: const Text('Query Architecture')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Fetch Behavior', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Control how much data is loaded in the foreground'),
          ),
          _buildSlider(
            context,
            label: 'Load Batch Size',
            value: settings.loadBatchSize.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            suffix: 'tweets',
            onChanged: (v) => notifier.updateLoadBatchSize(v.round()),
          ),
          _buildSlider(
            context,
            label: 'Prune Threshold',
            value: settings.pruneThreshold.toDouble(),
            min: 1000,
            max: 100000,
            divisions: 99,
            suffix: 'items',
            onChanged: (v) => notifier.updatePruneThreshold(v.round()),
          ),
          const Divider(),
          const ListTile(
            title: Text('Background Sync', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Control periodic background updates'),
          ),
          _buildSlider(
            context,
            label: 'Sync Interval',
            value: settings.syncInterval.toDouble(),
            min: 1,
            max: 120,
            divisions: 119,
            suffix: 'minutes',
            onChanged: (v) => notifier.updateSyncInterval(v.round()),
          ),
          _buildSlider(
            context,
            label: 'Sync Batch Size',
            value: settings.syncBatchSize.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            suffix: 'subs',
            onChanged: (v) => notifier.updateSyncBatchSize(v.round()),
          ),
          const Divider(),
          const ListTile(
            title: Text('Rate Limiting', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Control behavior after 429 errors'),
          ),
          _buildSlider(
            context,
            label: 'Cooldown Duration',
            value: settings.cooldownDuration.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            suffix: 'minutes',
            onChanged: (v) => notifier.updateCooldownDuration(v.round()),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Note: These parameters affect how quickly you reach Twitter/X rate limits. Higher batch sizes and lower intervals are more aggressive.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${value.round()} $suffix', style: const TextStyle(color: Colors.blue)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
