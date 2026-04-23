# Feed Discovery Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a multi-stage discovery pipeline for the TikTok-style feed that balances freshness, diversity, and subscription priority using user-controllable weights.

**Architecture:** A decoupled `DiscoveryEngine` class handles candidates from SQL and API, interleaves them into "slots" based on a fresh-mix ratio, and applies a saturation penalty to prevent account dominance.

**Tech Stack:** Flutter, Riverpod, SQLite (sqflite)

---

### Task 1: Settings Extension

**Files:**
- Modify: `lib/features/settings/settings_provider.dart`
- Test: `test/features/settings/settings_provider_test.dart`

- [ ] **Step 1: Update SettingsState**
Add the new discovery parameters to the `SettingsState` class.

```dart
class SettingsState {
  // ... existing fields
  final bool avoidWatchedContent;
  final bool unseenSubscriptionBoost;
  final double freshMixRatio;
  final int saturationThreshold;
  final FeedSort fetchStrategy;
  final int initialSyncCount;

  SettingsState({
    // ...
    this.avoidWatchedContent = true,
    this.unseenSubscriptionBoost = true,
    this.freshMixRatio = 0.3,
    this.saturationThreshold = 2,
    this.fetchStrategy = FeedSort.latest,
    this.initialSyncCount = 10,
  });

  SettingsState copyWith({
    // ...
    bool? avoidWatchedContent,
    bool? unseenSubscriptionBoost,
    double? freshMixRatio,
    int? saturationThreshold,
    FeedSort? fetchStrategy,
    int? initialSyncCount,
  }) {
    return SettingsState(
      // ...
      avoidWatchedContent: avoidWatchedContent ?? this.avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost ?? this.unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio ?? this.freshMixRatio,
      saturationThreshold: saturationThreshold ?? this.saturationThreshold,
      fetchStrategy: fetchStrategy ?? this.fetchStrategy,
      initialSyncCount: initialSyncCount ?? this.initialSyncCount,
    );
  }
}
```

- [ ] **Step 2: Update SettingsNotifier**
Update `_init` and add update methods for the new fields.

```dart
  Future<void> _init() async {
    // ...
    final avoidWatchedContent = _prefs.getBool('avoidWatchedContent') ?? true;
    final unseenSubscriptionBoost = _prefs.getBool('unseenSubscriptionBoost') ?? true;
    final freshMixRatio = _prefs.getDouble('freshMixRatio') ?? 0.3;
    final saturationThreshold = _prefs.getInt('saturationThreshold') ?? 2;
    final fetchStrategyIdx = _prefs.getInt('fetchStrategy') ?? 0;
    final initialSyncCount = _prefs.getInt('initialSyncCount') ?? 10;

    state = SettingsState(
      // ...
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      fetchStrategy: fetchStrategyIdx < FeedSort.values.length ? FeedSort.values[fetchStrategyIdx] : FeedSort.latest,
      initialSyncCount: initialSyncCount,
    );
  }

  void updateDiscoveryParam({
    bool? avoidWatchedContent,
    bool? unseenSubscriptionBoost,
    double? freshMixRatio,
    int? saturationThreshold,
    FeedSort? fetchStrategy,
    int? initialSyncCount,
  }) {
    state = state.copyWith(
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      fetchStrategy: fetchStrategy,
      initialSyncCount: initialSyncCount,
    );
    if (avoidWatchedContent != null) _prefs.setBool('avoidWatchedContent', avoidWatchedContent);
    if (unseenSubscriptionBoost != null) _prefs.setBool('unseenSubscriptionBoost', unseenSubscriptionBoost);
    if (freshMixRatio != null) _prefs.setDouble('freshMixRatio', freshMixRatio);
    if (saturationThreshold != null) _prefs.setInt('saturationThreshold', saturationThreshold);
    if (fetchStrategy != null) _prefs.setInt('fetchStrategy', fetchStrategy.index);
    if (initialSyncCount != null) _prefs.setInt('initialSyncCount', initialSyncCount);
  }
```

- [ ] **Step 3: Run existing settings tests**
Run: `flutter test test/features/settings/settings_provider_test.dart`
Expected: PASS

---

### Task 2: Discovery Engine Core Logic

**Files:**
- Create: `lib/core/client/discovery_engine.dart`
- Test: `test/core/client/discovery_engine_test.dart`

- [ ] **Step 1: Write failing test for interleaving**
Verify that `DiscoveryEngine` can mix two lists based on a ratio.

```dart
void main() {
  test('interleaves fresh and cached items based on ratio', () {
    final fresh = List.generate(10, (i) => Tweet(id: 'f$i', text: 'fresh', userHandle: 'u', mediaUrls: []));
    final cached = List.generate(10, (i) => Tweet(id: 'c$i', text: 'cache', userHandle: 'u', mediaUrls: []));
    
    final result = DiscoveryEngine.interleave(fresh, cached, 0.3);
    
    // In a block of 10, we expect ~3 fresh items
    final freshCount = result.take(10).where((t) => t.id.startsWith('f')).length;
    expect(freshCount, 3);
  });
}
```

- [ ] **Step 2: Implement DiscoveryEngine.interleave**

```dart
class DiscoveryEngine {
  static List<Tweet> interleave(List<Tweet> fresh, List<Tweet> cached, double ratio) {
    final result = <Tweet>[];
    int freshIdx = 0;
    int cacheIdx = 0;

    while (freshIdx < fresh.length || cacheIdx < cached.length) {
      // For every 10 items, try to pick 'ratio * 10' from fresh
      double targetFreshCount = (result.length + 1) * ratio;
      int currentFreshCount = result.where((t) => fresh.contains(t)).length; // Simplified for plan

      if (freshIdx < fresh.length && (result.isEmpty || currentFreshCount < targetFreshCount.floor() + 1)) {
         result.add(fresh[freshIdx++]);
      } else if (cacheIdx < cached.length) {
         result.add(cached[cacheIdx++]);
      } else if (freshIdx < fresh.length) {
         result.add(fresh[freshIdx++]);
      } else {
        break;
      }
    }
    return result;
  }
}
```

- [ ] **Step 3: Verify tests pass**
Run: `flutter test test/core/client/discovery_engine_test.dart`

---

### Task 3: Saturation & Boost Logic

**Files:**
- Modify: `lib/core/client/discovery_engine.dart`
- Test: `test/core/client/discovery_engine_test.dart`

- [ ] **Step 1: Write test for saturation penalty**
Verify that it swaps items if a user appears too often.

```dart
  test('enforces saturation threshold by swapping items', () {
    final tweets = [
      Tweet(id: '1', userHandle: 'user_a', text: '', mediaUrls: []),
      Tweet(id: '2', userHandle: 'user_a', text: '', mediaUrls: []),
      Tweet(id: '3', userHandle: 'user_a', text: '', mediaUrls: []), // Third one!
      Tweet(id: '4', userHandle: 'user_b', text: '', mediaUrls: []),
    ];
    
    final result = DiscoveryEngine.applySaturation(tweets, threshold: 2);
    expect(result[2].userHandle, 'user_b');
  });
```

- [ ] **Step 2: Implement applySaturation**

```dart
  static List<Tweet> applySaturation(List<Tweet> tweets, {int threshold = 2}) {
    final result = List<Tweet>.from(tweets);
    final windowSize = 10;

    for (int i = 0; i < result.length; i++) {
      final start = (i - windowSize + 1).clamp(0, result.length);
      final window = result.sublist(start, i + 1);
      final handle = result[i].userHandle;
      final count = window.where((t) => t.userHandle == handle).length;

      if (count > threshold) {
        // Find a candidate to swap with from further down
        int swapIdx = -1;
        for (int j = i + 1; j < result.length; j++) {
          if (result[j].userHandle != handle) {
            swapIdx = j;
            break;
          }
        }
        if (swapIdx != -1) {
          final temp = result[i];
          result[i] = result[swapIdx];
          result[swapIdx] = temp;
        }
      }
    }
    return result;
  }
```

---

### Task 4: FeedProvider Integration

**Files:**
- Modify: `lib/features/feed/feed_provider.dart`

- [ ] **Step 1: Refactor build()**
Use `DiscoveryEngine` to generate the initial feed.

```dart
  @override
  FutureOr<FeedState> build() async {
    final client = ref.watch(twitterClientProvider);
    final settings = ref.watch(settingsProvider);
    
    // 1. Fetch Candidates (Parallel)
    final localFuture = Repository.getUnplayedCachedMedia(
      settings.loadBatchSize * 3,
      filters: settings.filters,
    );
    
    final freshFuture = client.fetchSubscribedMedia(
      sort: settings.fetchStrategy,
      filters: settings.filters,
      loadBatchSize: settings.initialSyncCount,
    );

    final results = await Future.wait([localFuture, freshFuture]);
    final localPool = results[0].tweets; // getUnplayedCachedMedia should return List<Tweet>
    final freshPool = results[1].tweets;

    // 2. Process via Engine
    var processed = DiscoveryEngine.interleave(freshPool, localPool, settings.freshMixRatio);
    processed = DiscoveryEngine.applySaturation(processed, threshold: settings.saturationThreshold);

    await Repository.insertCachedMedia(freshPool);
    
    return FeedState(tweets: processed, cursorBottom: results[1].cursorBottom);
  }
```

---

### Task 5: Query Settings UI

**Files:**
- Create: `lib/features/settings/query_settings_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create QuerySettingsScreen**
Add sliders and switches for the new discovery params.

```dart
class QuerySettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Query Architecture')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Avoid Watched Content'),
            value: settings.avoidWatchedContent,
            onChanged: (val) => notifier.updateDiscoveryParam(avoidWatchedContent: val),
          ),
          ListTile(title: Text('Freshness Mix Ratio')),
          Slider(
            value: settings.freshMixRatio,
            onChanged: (val) => notifier.updateDiscoveryParam(freshMixRatio: val),
          ),
          // ... other controls
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Link from SettingsScreen**
Add a navigation entry to the main settings page.
