# XFlow Settings & Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a centralized settings page and integrate sorting/filtering logic into the `FeedProvider`.

**Architecture:** A `SettingsProvider` (using `SharedPreferences`) will store user preferences. The `FeedProvider` will listen to these settings and refetch/resort the feed accordingly.

**Tech Stack:** Flutter, Riverpod, shared_preferences, Material 3

---

### Task 1: Implement Settings Provider

**Files:**
- Create: `lib/features/settings/settings_provider.dart`

- [ ] **Step 1: Create the `Settings` model and notifier**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, oldest }
enum MediaFilter { all, videoOnly, imageOnly }

class SettingsState {
  final FeedSort sort;
  final MediaFilter filter;
  final bool autoplay;

  SettingsState({
    this.sort = FeedSort.latest,
    this.filter = MediaFilter.all,
    this.autoplay = true,
  });

  SettingsState copyWith({FeedSort? sort, MediaFilter? filter, bool? autoplay}) {
    return SettingsState(
      sort: sort ?? this.sort,
      filter: filter ?? this.filter,
      autoplay: autoplay ?? this.autoplay,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _init();
    return SettingsState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      sort: FeedSort.values[_prefs.getInt('sort') ?? 0],
      filter: MediaFilter.values[_prefs.getInt('filter') ?? 0],
      autoplay: _prefs.getBool('autoplay') ?? true,
    );
  }

  void updateSort(FeedSort sort) {
    state = state.copyWith(sort: sort);
    _prefs.setInt('sort', sort.index);
  }

  void updateFilter(MediaFilter filter) {
    state = state.copyWith(filter: filter);
    _prefs.setInt('filter', filter.index);
  }

  void toggleAutoplay(bool value) {
    state = state.copyWith(autoplay: value);
    _prefs.setBool('autoplay', value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/settings_provider.dart
git commit -m "feat: add settings provider"
```

---

### Task 2: Integrate Sorting & Filtering in FeedProvider

**Files:**
- Modify: `lib/features/feed/feed_provider.dart`

- [ ] **Step 1: Update `feedProvider` to watch `settingsProvider`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/client/twitter_client.dart';
import '../../core/models/tweet.dart';
import '../settings/settings_provider.dart';

final feedProvider = FutureProvider<List<Tweet>>((ref) async {
  final client = ref.watch(twitterClientProvider);
  final settings = ref.watch(settingsProvider);
  
  var tweets = await client.fetchTrendingMedia();

  // Apply Filter
  if (settings.filter == MediaFilter.videoOnly) {
    tweets = tweets.where((t) => t.isVideo).toList();
  } else if (settings.filter == MediaFilter.imageOnly) {
    tweets = tweets.where((t) => !t.isVideo).toList();
  }

  // Apply Sort (Mock sorting for now)
  if (settings.sort == FeedSort.oldest) {
    tweets = tweets.reversed.toList();
  }

  return tweets;
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/feed/feed_provider.dart
git commit -m "feat: integrate sorting and filtering in feed provider"
```

---

### Task 3: Build Settings Screen

**Files:**
- Create: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create the M3 Settings Screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

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
          const ListTile(title: Text('Playback'), subtitle: Text('Manage your video experience')),
          SwitchListTile(
            title: const Text('Autoplay'),
            value: settings.autoplay,
            onChanged: notifier.toggleAutoplay,
          ),
          const Divider(),
          const ListTile(title: Text('Content'), subtitle: Text('Sort and filter media')),
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
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add Navigation from Feed to Settings**

```dart
// lib/features/feed/tiktok_feed_screen.dart
// Add an IconButton in a Stack overlay
IconButton(
  icon: const Icon(Icons.settings, color: Colors.white),
  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen())),
)
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/ lib/features/feed/tiktok_feed_screen.dart
git commit -m "feat: implement settings screen and navigation"
```
