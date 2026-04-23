# Design Spec: Feed Discovery Engine

**Date:** 2026-04-23
**Status:** Approved
**Topic:** Implementing a multi-stage discovery pipeline for the TikTok-style feed with user-controllable algorithm parameters.

## 1. Overview
Transition from a simple "Random/Latest" cache-first feed to a sophisticated "Discovery Engine" that balances freshness, diversity, and subscription priority. All parameters are exposed in a new "Query Architecture" settings page.

## 2. Algorithm Parameters (SettingsState)
The following parameters will be added to `SettingsState` and persisted via `SharedPreferences`:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `avoidWatchedContent` | `bool` | `true` | Exclude items with `played_count > 0` from initial candidate pool. |
| `unseenSubscriptionBoost` | `bool` | `true` | Prioritize accounts with the lowest total view count. |
| `freshMixRatio` | `double` | `0.3` | Ratio of fresh API fetches vs. cached items (0.0 to 1.0). |
| `saturationThreshold` | `int` | `2` | Max items from same account allowed in a 10-item window. |
| `fetchStrategy` | `FeedSort` | `latest` | How new items are fetched (latest, popular, trending, etc). |
| `initialSyncCount` | `int` | `10` | Number of new items to fetch immediately on app launch. |

## 3. The Discovery Pipeline
The `DiscoveryEngine` will process items in four stages:

### Stage 1: Candidate Retrieval
- **Local Pool:** SQL query: `SELECT * FROM cached_media WHERE played_count = 0 (if enabled) ORDER BY created_at DESC LIMIT loadBatchSize * 3`.
- **Fresh Pool:** Parallel API request to `fetchSubscribedMedia` with `initialSyncCount`.

### Stage 2: Selection & Interleaving (Bucket-Logic)
- Divide items into `FreshBucket` and `CacheBucket`.
- Construct a list by interleaving based on `freshMixRatio`. 
- *Example (Ratio 0.2):* Take 2 from Fresh, 8 from Cache.

### Stage 3: Diversity Enforcement (Saturation Penalty)
- Scan the interleaved list.
- If a user appears > `saturationThreshold` in a sliding 10-item window:
  - Find the offending item.
  - Swap it with the first available item from a *different* user further down the list.

### Stage 4: Metadata Enrichment
- Apply `unseenSubscriptionBoost` by slightly boosting the position of items from users with low `played_count` in the local DB.

## 4. UI Design: Query Architecture Page
A dedicated settings screen (accessible from standard Settings) containing:
- **Toggles:** "Avoid Watched Content", "Prioritize Unseen Subscribers".
- **Sliders:** "Freshness Mix" (0% to 100%), "Account Saturation" (1 to 5).
- **Selection:** "Global Fetch Strategy" (Latest, Popular, Trending).
- **Number Input:** "Initial App-Launch Fetch Count".

## 5. Implementation Strategy
1.  **Settings Extension:** Add new fields to `SettingsState` and `SettingsNotifier`.
2.  **DiscoveryEngine Class:** Create a pure Dart class `DiscoveryEngine` to handle the logic.
3.  **FeedNotifier Update:** Refactor `build()` to call `DiscoveryEngine.generateFeed()`.
4.  **UI Implementation:** Create `QuerySettingsScreen` and link from `SettingsScreen`.
5.  **Unit Tests:** Verify interleaving ratios and saturation swapping logic.
