import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/features/settings/settings_screen.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all settings options', (WidgetTester tester) async {
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
      
      expect(find.text('Sort Order'), findsOneWidget);
      expect(find.text('Autoplay'), findsOneWidget);
      
      // Scroll to find Storage
      await tester.scrollUntilVisible(find.text('Storage'), 100);
      expect(find.text('Storage'), findsOneWidget);
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
      sort: FeedSort.latest,
      autoplay: true,
      mediaCacheSizeMB: 500,
    );
  }

  @override
  void updateSort(FeedSort sort) {}

  @override
  void updateMediaCacheSize(int megabytes) {
    state = state.copyWith(mediaCacheSizeMB: megabytes);
  }
  
  @override
  void toggleAutoplay(bool value) {}
  
  @override
  void toggleFilter(MediaFilter filter) {}
}
