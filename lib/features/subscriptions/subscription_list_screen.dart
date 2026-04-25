import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/database/repository.dart';
import '../../core/database/entities.dart';
import '../../core/utils/media_cache_manager.dart';
import '../profile/user_details_screen.dart';
import '../../core/navigation/navigation_provider.dart';
import '../settings/settings_screen.dart';
import '../../core/client/account_provider.dart';
import '../auth/login_screen.dart';

enum SubscriptionSort {
  name,
  handle,
  followers,
  views,
}

class SubscriptionListState {
  final List<Subscription> allSubscriptions;
  final Map<String, int> userViews;
  final String searchQuery;
  final SubscriptionSort sort;
  final bool isAscending;
  final bool isLoading;

  SubscriptionListState({
    this.allSubscriptions = const [],
    this.userViews = const {},
    this.searchQuery = '',
    this.sort = SubscriptionSort.name,
    this.isAscending = true,
    this.isLoading = true,
  });

  List<Subscription> get filteredSubscriptions {
    List<Subscription> filtered = List.from(allSubscriptions);
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((sub) {
        return sub.name.toLowerCase().contains(query) ||
               sub.screenName.toLowerCase().contains(query);
      }).toList();
    }

    int multiplier = isAscending ? 1 : -1;

    switch (sort) {
      case SubscriptionSort.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()) * multiplier);
        break;
      case SubscriptionSort.handle:
        filtered.sort((a, b) => a.screenName.toLowerCase().compareTo(b.screenName.toLowerCase()) * multiplier);
        break;
      case SubscriptionSort.followers:
        filtered.sort((a, b) => (a.followersCount ?? 0).compareTo(b.followersCount ?? 0) * multiplier);
        break;
      case SubscriptionSort.views:
        filtered.sort((a, b) {
          final viewsA = userViews[a.screenName.toLowerCase()] ?? 0;
          final viewsB = userViews[b.screenName.toLowerCase()] ?? 0;
          return viewsA.compareTo(viewsB) * multiplier;
        });
        break;
    }
    return filtered;
  }

  SubscriptionListState copyWith({
    List<Subscription>? allSubscriptions,
    Map<String, int>? userViews,
    String? searchQuery,
    SubscriptionSort? sort,
    bool? isAscending,
    bool? isLoading,
  }) {
    return SubscriptionListState(
      allSubscriptions: allSubscriptions ?? this.allSubscriptions,
      userViews: userViews ?? this.userViews,
      searchQuery: searchQuery ?? this.searchQuery,
      sort: sort ?? this.sort,
      isAscending: isAscending ?? this.isAscending,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SubscriptionListNotifier extends Notifier<SubscriptionListState> {
  @override
  SubscriptionListState build() {
    _load();
    return SubscriptionListState();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repository.getSubscriptions(),
      Repository.getPlayedCountsByUser(),
    ]);
    
    state = state.copyWith(
      allSubscriptions: results[0] as List<Subscription>,
      userViews: results[1] as Map<String, int>,
      isLoading: false,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSort(SubscriptionSort sort) {
    state = state.copyWith(sort: sort);
  }

  void toggleOrder() {
    state = state.copyWith(isAscending: !state.isAscending);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _load();
  }
}

final subscriptionListProvider = NotifierProvider<SubscriptionListNotifier, SubscriptionListState>(
  SubscriptionListNotifier.new,
);

class SubscriptionListScreen extends ConsumerWidget {
  final bool isStandalone;

  const SubscriptionListScreen({super.key, this.isStandalone = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionListProvider);
    final account = ref.watch(accountProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final subs = state.filteredSubscriptions;

    Widget content = subs.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.searchQuery.isEmpty ? 'No subscriptions found.' : 'No results matching "${state.searchQuery}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                if (account == null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                    child: const Text('Login to X'),
                  ),
                ],
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              final views = state.userViews[sub.screenName.toLowerCase()] ?? 0;
              
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: sub.profileImageUrl != null
                        ? CachedNetworkImageProvider(
                            sub.profileImageUrl!,
                            cacheManager: CustomMediaCacheManager.getInstance(),
                          )
                        : null,
                    child: sub.profileImageUrl == null ? const Icon(Icons.person, size: 24) : null,
                  ),
                  title: Text(
                    sub.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '@${sub.screenName}${sub.followersCount != null ? " • ${_formatCount(sub.followersCount!)} followers" : ""}${views > 0 ? " • $views views" : ""}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                ),
              );
            },
          );

    return Scaffold(
      appBar: AppBar(
        leading: isStandalone ? null : IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(subscriptionListProvider.notifier).refresh(),
        ),
        title: Text(isStandalone ? 'Subscriptions' : 'My Subscriptions'),
        actions: [
          if (!isStandalone)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen()),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: _buildSearchAndSort(context, ref),
        ),
      ),
      body: content,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildSearchAndSort(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(subscriptionListProvider.notifier);
    final state = ref.watch(subscriptionListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          SearchBar(
            hintText: 'Search subscriptions...',
            onChanged: notifier.setSearchQuery,
            leading: const Icon(Icons.search),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHigh),
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
          ),
          const SizedBox(height: 8),
          const SubscriptionSortSettings(),
        ],
      ),
    );
  }
}

class SubscriptionSortSettings extends ConsumerWidget {
  const SubscriptionSortSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionListProvider);
    final notifier = ref.read(subscriptionListProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Sort by: ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          _SortChip(
            label: 'Name',
            isSelected: state.sort == SubscriptionSort.name,
            onTap: () => notifier.setSort(SubscriptionSort.name),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Handle',
            isSelected: state.sort == SubscriptionSort.handle,
            onTap: () => notifier.setSort(SubscriptionSort.handle),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Followers',
            isSelected: state.sort == SubscriptionSort.followers,
            onTap: () => notifier.setSort(SubscriptionSort.followers),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Cache Views',
            isSelected: state.sort == SubscriptionSort.views,
            onTap: () => notifier.setSort(SubscriptionSort.views),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: Icon(
              state.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            onPressed: notifier.toggleOrder,
            tooltip: state.isAscending ? 'Ascending' : 'Descending',
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: false,
    );
  }
}
