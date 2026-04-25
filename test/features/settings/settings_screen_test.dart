import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xflow/features/settings/settings_screen.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all settings options', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
            ],
            child: const MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        
        expect(find.text('Query Architecture'), findsOneWidget);
        expect(find.text('Autoplay'), findsOneWidget);
        
        // Scroll to find Storage
        await tester.scrollUntilVisible(find.text('Storage'), 100);
        expect(find.text('Storage'), findsOneWidget);
      });
    });

    testWidgets('updates media cache size via slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => MockSettingsNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(Slider), 100);
      
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      await tester.tap(sliderFinder);
      await tester.pump();

      expect(find.textContaining('Current quota:'), findsOneWidget);
    });
  });
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      fetchStrategy: FeedSort.latest,
      autoplay: true,
      mediaCacheSizeMB: 500,
    );
  }

  @override
  void updateMediaCacheSize(int megabytes) {
    state = state.copyWith(mediaCacheSizeMB: megabytes);
  }
  
  @override
  void toggleAutoplay(bool value) {}
  
  @override
  void toggleFilter(MediaFilter filter) {}

  @override
  void updateDiscoveryParam({
    bool? avoidWatchedContent,
    bool? unseenSubscriptionBoost,
    double? freshMixRatio,
    int? saturationThreshold,
    int? mediaSaturationThreshold,
    FeedSort? fetchStrategy,
    int? initialSyncCount,
    bool? strictSubscriptionsOnly,
    bool? includeNativeRetweets,
    bool? useChunkedSubscriptions,
    int? saturationWindow,
    int? unseenBoostLookahead,
    int? minFavesFilter,
    int? dbCandidateMultiplier,
    int? apiRetryLimit,
    int? chunkRotationLimit,
    int? pageRetryLimit,
    int? minNewTweetsThreshold,
    int? maxQueryLength,
    int? apiTimeoutSeconds,
    int? maxSaturationSwaps,
    int? maxSaturationPasses,
    int? playbackRetryLimit,
    int? autoSkipDelaySeconds,
    int? lazyLoadThreshold,
    int? mediaDeduplicationWindow,
    int? searchBatchSize,
    VideoEndAction? videoEndAction,
  }) {}
}
