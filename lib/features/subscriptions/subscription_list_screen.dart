import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/database/repository.dart';
import '../../core/database/entities.dart';
import '../profile/user_details_screen.dart';
import '../../core/navigation/navigation_provider.dart';
import '../settings/settings_screen.dart';

final subscriptionListProvider = FutureProvider<List<Subscription>>((ref) async {
  return Repository.getSubscriptions();
});

class SubscriptionListScreen extends ConsumerWidget {
  final bool isStandalone;

  const SubscriptionListScreen({super.key, this.isStandalone = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionListProvider);

    Widget content = subsAsync.when(
      data: (subs) {
        if (subs.isEmpty) {
          return const Center(
            child: Text('No subscriptions found.', style: TextStyle(color: Colors.white70)),
          );
        }
        return ListView.builder(
          itemCount: subs.length,
          itemBuilder: (context, index) {
            final sub = subs[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundImage: sub.profileImageUrl != null
                    ? CachedNetworkImageProvider(sub.profileImageUrl!)
                    : null,
                child: sub.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
              ),
              title: Text(
                sub.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '@${sub.screenName}',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                if (isStandalone) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDetailsScreen(screenName: sub.screenName),
                    ),
                  );
                } else {
                  ref.read(navigationProvider.notifier).selectUser(sub.screenName);
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
    );

    if (isStandalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscriptions')),
        body: content,
      );
    }

    return Column(
      children: [
        _buildTopPanel(context, ref),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildTopPanel(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () {
                ref.invalidate(subscriptionListProvider);
              },
            ),
            const Text(
              "My Subscriptions",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
