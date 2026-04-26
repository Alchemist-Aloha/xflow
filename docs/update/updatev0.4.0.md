# XFlow — Update v0.4.0

## Summary

Version `0.4.0` focuses on stability, performance, and extensibility: we improved background playback and sync reliability, optimized media caching and startup time, and shipped a set of UX improvements across feed and settings screens.

## Highlights

- **Background Playback & Low-Latency Start:** Improvements to audio/video warm-up and prefetch reduce perceived startup latency for media playback.
- **Offline-First Sync & Conflict Resolver:** Database sync was made more robust with deterministic conflict resolution and reduced duplicate content on resume.
- **Media Cache Optimizations:** Faster pruning and new cache metrics; cache pruning is now incremental and configurable from settings.
- **UI/UX Polishes:** Updated timeline headers, subscription sorting, and accessibility improvements on the settings and discovery screens.
- **Build & Platform:** Web build size improvements and Android packaging fixes to reduce cold-start time.

## Changelog (selected changes)

- feat: implement incremental media cache pruning and metrics
- fix: reduce startup latency by eager media prefetch and decoder warm-up
- feat: add deterministic conflict resolver for sync operations
- perf: optimize DB indices for timeline queries
- chore: improve web build pipeline and Android packaging
- feat: accessibility: improve contrast and screen-reader labels in settings

## Notable files changed / new

- lib/core/plugin/ — new plugin host and registration API
- lib/features/media/mixer_plugin.dart — plugin interface for media mixers
- lib/core/cache/media_cache_manager.dart — incremental pruning and metrics
- lib/core/sync/conflict_resolver.dart — deterministic conflict resolution
- lib/features/settings/query_settings_screen.dart — exposure of new cache and sync toggles
- web/ and android/ build tweaks in respective build configs

## Migration notes

- If you rely on the older media mixer implementation, update your code to register via the new plugin API (`lib/core/plugin/`). See plugin host docs for lifecycle and priority rules.
- New cache pruning defaults are conservative; if you previously relied on aggressive pruning, adjust values in Settings → Storage.
