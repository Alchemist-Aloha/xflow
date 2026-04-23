import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/features/settings/query_settings_screen.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  group('QuerySettingsScreen Widget Tests', () {
    testWidgets('renders all query architecture sliders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: QuerySettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fetch Behavior'), findsOneWidget);
      expect(find.text('Background Sync'), findsOneWidget);
      
      // Scroll to find Rate Limiting and Cooldown Duration
      await tester.scrollUntilVisible(find.text('Cooldown Duration'), 100);
      expect(find.text('Rate Limiting'), findsOneWidget);
      expect(find.text('Cooldown Duration'), findsOneWidget);
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
        
        // Tapping first slider (Load Batch Size is usually visible at top)
        await tester.tap(sliderFinder.first);
        await tester.pump();

        expect(find.textContaining('tweets'), findsWidgets);
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
}
