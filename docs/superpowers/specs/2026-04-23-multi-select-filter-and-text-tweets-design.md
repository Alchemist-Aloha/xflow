# Design Spec: Multi-Selection Filtering & Text Tweet Support

**Date:** 2026-04-23
**Status:** In Review
**Topic:** Improving content filtering and adding support for text-only tweets in the TikTok-style feed.

## 1. Overview
Currently, the app only supports single-selection media filtering and exclusively shows tweets with media. This spec outlines the transition to a multi-selection filter (using chips) and the inclusion of text-only tweets, presented as elegant "Quote Cards" within the vertical feed.

## 2. Data Model Changes
### enum MediaFilter
Remove `all` and add `text`.
```dart
enum MediaFilter { video, image, gif, text }
```

### SettingsState
Change `filter` from a single enum to a `Set`.
```dart
class SettingsState {
  final Set<MediaFilter> filters; // Default: {} (implies All)
  // ...
}
```

## 3. State Management (SettingsProvider)
- **toggleFilter(MediaFilter):** Adds or removes a filter from the set.
- **Persistence:** Use `_prefs.setStringList('filters', ...)` to save the set as strings.
- **Initialization:** Convert stored string list back to `Set<MediaFilter>`.

## 4. Content Fetching (TwitterClient)
- **Base Query:** Default `finalQuery` will no longer include `filter:media` by default.
- **Filter Logic:**
  - If `filters` is empty: Default to "All" (no filters added).
  - If `filters` contains items:
    - Construct a group of OR-joined filters:
      - `video` -> `filter:videos`
      - `image` -> `filter:images`
      - `gif` -> `filter:consumer_video`
      - `text` -> `-filter:media`
    - Example: `{video, text}` -> `(filter:videos OR -filter:media)`
    - Example: `{image}` -> `filter:images`
- **Parsing:** Remove `if (allMedia.isEmpty) return;` in `parseTweetResult` to allow text-only tweets to be added to the result list.

## 5. UI Design
### Settings Screen
- Replace the `DropdownButton` with a `Wrap` containing `FilterChip` widgets.
- Each chip toggles a `MediaFilter`.
- If no chips are selected, the UI should indicate that "All Content" is being shown.

### Text-Only Feed Item
- **Background:** Material 3 `LinearGradient` (e.g., `surfaceContainer` to `surface`).
- **Typography:** Large, centered text using `displaySmall` or `headlineMedium`.
- **Layout:** Standard TikTok overlay (avatar, handle, actions) remains on top of the text card.

## 6. Implementation Strategy
1. Update `MediaFilter` enum and `SettingsState`.
2. Update `SettingsNotifier` for multi-selection logic and persistence.
3. Modify `TwitterClient` to support text tweets and complex filtering queries.
4. Implement `FilterChip` UI in `SettingsScreen`.
5. Create `TextTweetCard` widget and integrate it into `TiktokPlayerItem`.
