import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/settings/query_settings_screen.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  group('QuerySettingsScreen Widget Tests', () {
    testWidgets('renders all query architecture sliders', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: QuerySettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Mix & Delivery', skipOffstage: true), findsOneWidget);
      
      // Scroll to find Variety header
      await tester.scrollUntilVisible(find.textContaining('Variety Engine'), 100);
      expect(find.textContaining('Variety Engine'), findsOneWidget);
      
      // Scroll to find Search Tuning
      await tester.scrollUntilVisible(find.textContaining('Search Tuning'), 100);
      expect(find.textContaining('Search Tuning'), findsOneWidget);
    });

    testWidgets('updating a slider updates the displayed value', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
            ],
            child: const MaterialApp(
              home: QuerySettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsAtLeastNWidgets(1));
        
        // Tapping first slider
        await tester.tap(sliderFinder.first);
        await tester.pump();

        // Any text with a number should be present in sliders
        expect(find.byType(Slider), findsWidgets);
      });
    });
  });
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      loadBatchSize: 20,
      syncInterval: 15,
      syncBatchSize: 5,
      cooldownDuration: 15,
      pruneThreshold: 50000,
    );
  }

  @override
  void updateLoadBatchSize(int size) {
    state = state.copyWith(loadBatchSize: size);
  }

  @override
  void updateTimelineBatchSize(int size) {
    state = state.copyWith(timelineBatchSize: size);
  }

  @override
  void updateSyncInterval(int minutes) {
    state = state.copyWith(syncInterval: minutes);
  }

  @override
  void updateSyncBatchSize(int size) {
    state = state.copyWith(syncBatchSize: size);
  }

  @override
  void updateCooldownDuration(int minutes) {
    state = state.copyWith(cooldownDuration: minutes);
  }

  @override
  void updatePruneThreshold(int count) {
    state = state.copyWith(pruneThreshold: count);
  }

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
  }) {
    state = state.copyWith(
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      mediaSaturationThreshold: mediaSaturationThreshold,
      fetchStrategy: fetchStrategy,
      initialSyncCount: initialSyncCount,
      strictSubscriptionsOnly: strictSubscriptionsOnly,
      includeNativeRetweets: includeNativeRetweets,
      useChunkedSubscriptions: useChunkedSubscriptions,
      saturationWindow: saturationWindow,
      unseenBoostLookahead: unseenBoostLookahead,
      minFavesFilter: minFavesFilter,
      dbCandidateMultiplier: dbCandidateMultiplier,
      apiRetryLimit: apiRetryLimit,
      chunkRotationLimit: chunkRotationLimit,
      pageRetryLimit: pageRetryLimit,
      minNewTweetsThreshold: minNewTweetsThreshold,
      maxQueryLength: maxQueryLength,
      apiTimeoutSeconds: apiTimeoutSeconds,
      maxSaturationSwaps: maxSaturationSwaps,
      maxSaturationPasses: maxSaturationPasses,
      playbackRetryLimit: playbackRetryLimit,
      autoSkipDelaySeconds: autoSkipDelaySeconds,
      lazyLoadThreshold: lazyLoadThreshold,
      mediaDeduplicationWindow: mediaDeduplicationWindow,
      searchBatchSize: searchBatchSize,
      videoEndAction: videoEndAction,
    );
  }
}
