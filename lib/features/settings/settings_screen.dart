import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/client/twitter_account.dart';
import '../feed/feed_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Playback',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Manage your video experience'),
          ),
          SwitchListTile(
            title: const Text('Autoplay'),
            value: settings.autoplay,
            onChanged: (v) => notifier.toggleAutoplay(v),
          ),
          const Divider(),
          const ListTile(
            title: Text('Content',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Sort and filter media'),
          ),
          ListTile(
            title: const Text('Sort Order'),
            trailing: DropdownButton<FeedSort>(
              value: settings.sort,
              items: FeedSort.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => v != null ? notifier.updateSort(v) : null,
            ),
          ),
          ListTile(
            title: const Text('Media Filter'),
            trailing: DropdownButton<MediaFilter>(
              value: settings.filter,
              items: MediaFilter.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (v) => v != null ? notifier.updateFilter(v) : null,
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Account',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Manage your X account'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await TwitterAccount.logout();
              ref.invalidate(feedProvider);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),

        ],
      ),
    );
  }
}
