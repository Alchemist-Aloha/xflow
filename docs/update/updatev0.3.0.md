# XFlow — Update v0.3.0

## Summary

This release introduces the **Discovery Engine**, a powerful new system for feed generation, along with significant overhauls to the settings architecture, media caching, and Twitter authentication. Version `0.3.0` focuses on giving users more control over their feed algorithm and improving the overall stability of data synchronization.

## Highlights

- **Discovery Engine:** A new core engine (`lib/core/client/discovery_engine.dart`) that manages feed generation with user-controllable parameters, including media saturation logic to avoid consecutive user repeats, unseen content boosts, and multi-pass logic for diverse content discovery.
- **Feed Strategies:** Support for multiple timeline fetching strategies including Video Mixer (algorithmic), Chronological, and specialized Discovery modes.
- **Settings Overhaul:** Completely redesigned Settings page with a new `QuerySettingsScreen`. Users can now fine-tune batch sizes, sync intervals, and discovery parameters via interactive sliders and toggles.
- **Media Cache Management:** Implementation of a rolling media cache with SQLite tracking (`cached_media` table). Added cache statistics and a "Clear Cache" functionality in the settings for better storage management.
- **Background Sync:** Added background synchronization for metadata and automated startup pruning to keep the local database healthy and performant.
- **Authentication & Core:** Added account provider support for Twitter authentication and enhanced the `TwitterClient` with improved timeout handling and flexible fetching parameters.

## Changelog (selected commits)

- b682f8c — feat: add color resources and account provider for Twitter authentication
- ad8ba89 — overhaul settings page, sort subscriptions, and new icons
- d3c6ef2 — feat: add timeline batch size setting and update fetch logic in FeedNotifier
- 1b88fe8 — feat: add support for video mixer, algorithmic, and chronological feeds
- 7f561e1 — feat: add Debug Timeline screen for testing official Twitter API fetch
- 21d531c — feat: enhance Tweet model and Repository for media_key support and database deduplication
- 4fdc3e1 — feat: enhance DiscoveryEngine with media saturation and multi-pass logic
- ad958d2 — feat: implement Feed Discovery Engine with user-controllable parameters
- a2ad980 — feat: add cached_media table and pruning logic to SQLite
- d50a8c2 — feat: implement background sync for metadata and startup pruning

## Notable files referenced

- `lib/core/client/discovery_engine.dart` — The new heart of feed generation.
- `lib/features/settings/query_settings_screen.dart` — UI for advanced discovery and fetch parameters.
- `lib/core/database/` — Updated schema for media caching and tweet deduplication.
- `lib/core/client/background_sync.dart` — Logic for background metadata updates.
- `lib/core/client/account_provider.dart` — Twitter authentication and account management.
