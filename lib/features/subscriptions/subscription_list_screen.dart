import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/database/repository.dart';
import '../../core/database/entities.dart';
import '../../core/utils/media_cache_manager.dart';
import '../profile/user_details_screen.dart';
import '../../core/navigation/navigation_provider.dart';
import '../settings/settings_screen.dart';

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

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final subs = state.filteredSubscriptions;

    Widget content = subs.isEmpty
        ? Center(
            child: Text(
              state.searchQuery.isEmpty ? 'No subscriptions found.' : 'No results matching "${state.searchQuery}"',
              style: const TextStyle(color: Colors.white70),
            ),
          )
        : ListView.builder(
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              final views = state.userViews[sub.screenName.toLowerCase()] ?? 0;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: sub.profileImageUrl != null
                      ? CachedNetworkImageProvider(
                          sub.profileImageUrl!,
                          cacheManager: CustomMediaCacheManager.getInstance(),
                        )
                      : null,
                  child: sub.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
                ),
                title: Text(
                  sub.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '@${sub.screenName}${sub.followersCount != null ? " • ${_formatCount(sub.followersCount!)} followers" : ""}${views > 0 ? " • $views views" : ""}',
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

    if (isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscriptions'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: _buildSearchAndSort(context, ref),
          ),
        ),
        body: content,
      );
    }

    return Column(
      children: [
        _buildTopPanel(context, ref),
        _buildSearchAndSort(context, ref),
        Expanded(child: content),
      ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Column(
        children: [
          TextField(
            onChanged: notifier.setSearchQuery,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search subscriptions...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 8),
          const SubscriptionSortSettings(),
        ],
      ),
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
                ref.read(subscriptionListProvider.notifier).refresh();
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
          const Text('Sort by: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
          const SizedBox(width: 12),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: Icon(
              state.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.blue,
              size: 18,
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
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
        backgroundColor: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
