# XFlow — Update v0.2.0

## Summary

This release marks the project version `0.2.0` and bundles several player, feed, caching, and profile improvements focused on rendering reliability, media prefetching, and developer tooling.

## Highlights

- **Rendering & player:** Improved video rendering (wrapped `TiktokMediaContainer` in `RepaintBoundary`) and stabilized the player pool and prefetch logic (`lib/features/player/`, `lib/features/feed/`).
- **Feed & parsing:** Added timeline fetching helpers and improved tweet/date parsing to support more robust feed display and overlays.
- **Caching & performance:** Aggressive media and response caching using `ffcache`, `cached_network_image`, and local caching strategies to reduce buffering and network usage.
- **Profile & subscriptions:** Enhanced profile media display, feature flags for profile label improvements, subscription import and management screens.
- **Developer & CI:** Added `AppLogger` and `LogViewerScreen` for diagnostics and a GitHub Actions workflow for automated APK builds.

## Changelog (selected commits)

- c3ef2d5 — feat: wrap TiktokMediaContainer in RepaintBoundary for improved rendering
- a82febe — feat: add high-resolution avatar URL support for tweets and profiles
- e8bbeae — feat: add fetchUserTimelineByScreenName method and enhance tweet prefetching logic
- 272d4eb — feat: implement caching in fetch method and enhance feed with media warmup
- 15209d4 — feat: add player pool and prefetch logic
- c835425 — feat: implement AppLogger and LogViewerScreen for diagnostics
- ba23ebc — feat: add GitHub Actions workflow for building and releasing APKs
- cd6f7ab — feat: update project version to 0.2.0 and add release notes

Full recent history is available in the git log for the repository if you want an exhaustive list.

## Notable files referenced

- `pubspec.yaml` — version bump and dependency list
- `lib/features/player/` — player pool and rendering components
- `lib/features/feed/` — TikTok-style feed, warmup/prefetch logic
- `lib/core/client/twitter_client.dart` — Twitter/X client flags and fetch logic
- `squawker_source/` — upstream auth/data-layer reference

## Known issues & TODOs

- The codebase contains several `TODO` comments within `squawker_source/` and profile-related code; these are non-blocking but worth addressing in follow-up patches.

## Testing / Local verification

Run locally:

```bash
flutter pub get
flutter run
```

Run unit/widget tests and CI workflows where available to validate platform-specific builds.

