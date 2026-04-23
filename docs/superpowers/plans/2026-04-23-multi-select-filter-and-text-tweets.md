# Multi-Selection Filtering & Text Tweet Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the media filter into a multi-selection chip-based UI and add support for text-only tweets in the TikTok-style feed.

**Architecture:** 
- Update `SettingsProvider` to manage a `Set<MediaFilter>`.
- Refactor `TwitterClient` to construct complex queries and parse text tweets.
- Add `TextTweetCard` UI for text-only content.
- Update `SettingsScreen` with Material 3 `FilterChip` widgets.

**Tech Stack:** Flutter, Riverpod, shared_preferences, Material 3

---

### Task 1: Update MediaFilter Enum and SettingsState

**Files:**
- Modify: `lib/features/settings/settings_provider.dart`

- [ ] **Step 1: Update `MediaFilter` enum**
Remove `all` and add `text`.

```dart
enum MediaFilter { video, image, gif, text }
```

- [ ] **Step 2: Update `SettingsState` to use `Set<MediaFilter>`**

```dart
class SettingsState {
  final FeedSort sort;
  final Set<MediaFilter> filters; // Changed from 'filter'
  final bool autoplay;

  SettingsState({
    this.sort = FeedSort.latest,
    this.filters = const {}, // Default to empty set (All)
    this.autoplay = true,
  });

  SettingsState copyWith({FeedSort? sort, Set<MediaFilter>? filters, bool? autoplay}) {
    return SettingsState(
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      autoplay: autoplay ?? this.autoplay,
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/settings_provider.dart
git commit -m "refactor: update MediaFilter enum and SettingsState for multi-selection"
```

---

### Task 2: Update SettingsNotifier for Multi-Selection and Persistence

**Files:**
- Modify: `lib/features/settings/settings_provider.dart`

- [ ] **Step 1: Update `_init` and `toggleFilter` methods**

```dart
class SettingsNotifier extends Notifier<SettingsState> {
  // ...
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final sortIdx = _prefs.getInt('sort') ?? 0;
    final filterStrings = _prefs.getStringList('filters') ?? [];
    
    final filters = filterStrings
        .map((s) => MediaFilter.values.firstWhere((f) => f.name == s))
        .toSet();

    state = SettingsState(
      sort: sortIdx < FeedSort.values.length ? FeedSort.values[sortIdx] : FeedSort.latest,
      filters: filters,
      autoplay: _prefs.getBool('autoplay') ?? true,
    );
  }

  void toggleFilter(MediaFilter filter) {
    final nextFilters = Set<MediaFilter>.from(state.filters);
    if (nextFilters.contains(filter)) {
      nextFilters.remove(filter);
    } else {
      nextFilters.add(filter);
    }
    state = state.copyWith(filters: nextFilters);
    _prefs.setStringList('filters', nextFilters.map((f) => f.name).toList());
  }
  // ...
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/settings_provider.dart
git commit -m "feat: implement multi-selection logic and persistence in SettingsNotifier"
```

---

### Task 3: Refactor TwitterClient for Complex Filtering and Text Tweets

**Files:**
- Modify: `lib/core/client/twitter_client.dart`

- [ ] **Step 1: Update query building in `fetchTrendingMedia`**

```dart
Future<TweetResponse> fetchTrendingMedia({String? cursor, String? query, FeedSort? sort, Set<MediaFilter>? filters}) async {
  String finalQuery = query ?? "";
  
  if (filters != null && filters.isNotEmpty) {
    final filterQueries = <String>[];
    for (final f in filters) {
      switch (f) {
        case MediaFilter.video:
          filterQueries.add("filter:videos");
          break;
        case MediaFilter.image:
          filterQueries.add("filter:images");
          break;
        case MediaFilter.gif:
          filterQueries.add("filter:consumer_video");
          break;
        case MediaFilter.text:
          filterQueries.add("-filter:media");
          break;
      }
    }
    final combinedFilter = "(${filterQueries.join(' OR ')})";
    finalQuery = finalQuery.isEmpty ? combinedFilter : "$finalQuery $combinedFilter";
  } else if (query == null) {
    // Default "All" case if no specific query provided
    finalQuery = "filter:media OR -filter:media"; 
  }

  // ... min_faves logic remains
}
```

- [ ] **Step 2: Remove strict media check in `parseTweetResult`**

```dart
void parseTweetResult(Map<String, dynamic> itemContent, String entryId, List<Tweet> tweets) {
  // ...
  // Find and REMOVE: if (allMedia.isEmpty) return;
  // This allows text-only tweets to pass through.
}
```

- [ ] **Step 3: Update `fetchSubscribedMedia` and `fetchUserTweets` signatures**
Change `MediaFilter? filter` to `Set<MediaFilter>? filters`.

- [ ] **Step 4: Commit**

```bash
git add lib/core/client/twitter_client.dart
git commit -m "feat: support multi-filter queries and text tweet parsing in TwitterClient"
```

---

### Task 4: Update SettingsScreen UI with FilterChips

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Replace Dropdown with Wrap of FilterChips**

```dart
ListTile(
  title: const Text('Media Filter'),
  subtitle: const Text('Select multiple content types'),
),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: Wrap(
    spacing: 8.0,
    children: MediaFilter.values.map((filter) {
      final isSelected = settings.filters.contains(filter);
      return FilterChip(
        label: Text(filter.name.toUpperCase()),
        selected: isSelected,
        onSelected: (_) => notifier.toggleFilter(filter),
      );
    }).toList(),
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/settings_screen.dart
git commit -m "feat: implement multi-select FilterChips in SettingsScreen"
```

---

### Task 5: Implement TextTweetCard and Update TiktokPlayerItem

**Files:**
- Create: `lib/features/feed/widgets/text_tweet_card.dart`
- Modify: `lib/features/feed/widgets/tweet_text_overlay.dart` (if needed)
- Modify: `lib/features/player/widgets/media_container.dart` (to handle text-only)

- [ ] **Step 1: Create `TextTweetCard`**

```dart
class TextTweetCard extends StatelessWidget {
  final String text;
  const TextTweetCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainer,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `MediaContainer` to display `TextTweetCard` if no media**

- [ ] **Step 3: Commit**

```bash
git add lib/features/feed/widgets/text_tweet_card.dart lib/features/player/widgets/media_container.dart
git commit -m "feat: add TextTweetCard and integrate into media container"
```
