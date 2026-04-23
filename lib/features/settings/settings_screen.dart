import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/client/twitter_account.dart';
import '../../core/database/repository.dart';
import '../feed/feed_provider.dart';
import '../subscriptions/subscription_import_screen.dart';
import 'log_viewer_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Playback', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Manage your video experience'),
          ),
          SwitchListTile(
            title: const Text('Autoplay'),
            value: settings.autoplay,
            onChanged: (v) => notifier.toggleAutoplay(v),
          ),
          const Divider(),
          const ListTile(
            title: Text('Content', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Sort and filter media'),
          ),
          ListTile(
            title: const Text('Sort Order'),
            trailing: DropdownButton<FeedSort>(
              value: settings.sort,
              items: FeedSort.values.map((s) => DropdownMenuItem(
                value: s, 
                child: Text(s.name.toUpperCase())
              )).toList(),
              onChanged: (v) => v != null ? notifier.updateSort(v) : null,
            ),
          ),
          ListTile(
            title: const Text('Media Filter'),
            subtitle: Text(
              settings.filters.isEmpty 
                ? 'Showing all content' 
                : 'Filtering by: ${settings.filters.map((f) => f.name.toUpperCase()).join(", ")}'
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: MediaFilter.values.map((f) => FilterChip(
                label: Text(f.name.toUpperCase()),
                selected: settings.filters.contains(f),
                onSelected: (_) => notifier.toggleFilter(f),
              )).toList(),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Manage accounts to populate your feed'),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Import Subscriptions'),
            subtitle: const Text('Import from an existing X account'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SubscriptionImportScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.orange),
            title: const Text('Clear Subscriptions', style: TextStyle(color: Colors.orange)),
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await Repository.clearSubscriptions();
              ref.invalidate(feedNotifierProvider);
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('All subscriptions cleared')),
                );
              }
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Manage your X account'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final navigator = Navigator.of(context);
              await TwitterAccount.logout();
              ref.invalidate(feedNotifierProvider);
              if (mounted) {
                navigator.pop();
              }
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Debug', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Developer tools and diagnostics'),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('App Logs'),
            subtitle: const Text('View internal diagnostic logs'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const LogViewerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
