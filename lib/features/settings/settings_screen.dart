import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/client/twitter_account.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/repository.dart';
import '../feed/feed_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _importController = TextEditingController();
  bool _isImporting = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _importFromUser() async {
    final screenName = _importController.text.trim();
    if (screenName.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final client = TwitterClient();
      final user = await client.fetchUserByScreenName(screenName);
      if (user != null) {
        final following = await client.fetchFollowing(user.id);
        if (following.isNotEmpty) {
          await Repository.insertSubscriptions(following);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported ${following.length} accounts from @$screenName')),
            );
            ref.invalidate(feedProvider);
          }
        } else {
          throw Exception('No following accounts found or failed to fetch.');
        }
      } else {
        throw Exception('User @$screenName not found.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

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
              items: FeedSort.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
              onChanged: (v) => v != null ? notifier.updateSort(v) : null,
            ),
          ),
          ListTile(
            title: const Text('Media Filter'),
            trailing: DropdownButton<MediaFilter>(
              value: settings.filter,
              items: MediaFilter.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
              onChanged: (v) => v != null ? notifier.updateFilter(v) : null,
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            subtitle: Text('Import accounts to populate your feed'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _importController,
                        decoration: const InputDecoration(
                          hintText: 'X Screen Name (e.g. elonmusk)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isImporting
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _importFromUser,
                            child: const Text('Import'),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will fetch the "Following" list of the specified user and add them to your subscriptions.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.orange),
            title: const Text('Clear Subscriptions', style: TextStyle(color: Colors.orange)),
            onTap: () async {
              await Repository.clearSubscriptions();
              ref.invalidate(feedProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
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
