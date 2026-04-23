import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  group('SettingsNotifier Initialization', () {
    test('initial state with empty SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // We wait for the async _init to finish.
      // Since it's called synchronously in build(), we wait for microtasks.
      // A robust way in Riverpod is to read the provider and wait a tick.
      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final state = container.read(settingsProvider);

      expect(state.sort, FeedSort.latest);
      expect(state.filters, isEmpty);
      expect(state.autoplay, true);
      expect(state.isListView, false);
    });

    test('initial state with existing SharedPreferences values', () async {
      SharedPreferences.setMockInitialValues({
        'sort': FeedSort.popular.index,
        'filters': [MediaFilter.video.name, 'invalid_filter'],
        'autoplay': false,
        'isListView': true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final state = container.read(settingsProvider);

      expect(state.sort, FeedSort.popular);
      // 'invalid_filter' should be ignored
      expect(state.filters, {MediaFilter.video});
      expect(state.autoplay, false);
      expect(state.isListView, true);
    });

    test('initial state handles out-of-bounds sort index gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'sort': 999, // Out of bounds
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final state = container.read(settingsProvider);

      // Should default to latest if out of bounds
      expect(state.sort, FeedSort.latest);
    });
  });

  group('SettingsNotifier Updates', () {
    test('updateSort updates state and SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(settingsProvider.notifier);

      notifier.updateSort(FeedSort.oldest);

      final state = container.read(settingsProvider);
      expect(state.sort, FeedSort.oldest);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('sort'), FeedSort.oldest.index);
    });

    test('toggleFilter toggles filters correctly in state and SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(settingsProvider.notifier);

      // Add a filter
      notifier.toggleFilter(MediaFilter.image);

      var state = container.read(settingsProvider);
      expect(state.filters, {MediaFilter.image});

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('filters'), [MediaFilter.image.name]);

      // Add another filter
      notifier.toggleFilter(MediaFilter.video);

      state = container.read(settingsProvider);
      expect(state.filters, {MediaFilter.image, MediaFilter.video});

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('filters'), containsAll([MediaFilter.image.name, MediaFilter.video.name]));

      // Remove the first filter
      notifier.toggleFilter(MediaFilter.image);

      state = container.read(settingsProvider);
      expect(state.filters, {MediaFilter.video});

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('filters'), [MediaFilter.video.name]);
    });

    test('toggleAutoplay updates state and SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'autoplay': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(settingsProvider.notifier);

      notifier.toggleAutoplay(false);

      final state = container.read(settingsProvider);
      expect(state.autoplay, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('autoplay'), false);
    });

    test('toggleListView updates state and SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'isListView': false});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(settingsProvider.notifier);

      notifier.toggleListView(true);

      final state = container.read(settingsProvider);
      expect(state.isListView, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isListView'), true);
    });
  });
}
