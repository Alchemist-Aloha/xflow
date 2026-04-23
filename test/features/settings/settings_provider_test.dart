import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/features/settings/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsNotifier Persistence Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'loadBatchSize': 30,
        'syncInterval': 10,
        'cooldownDuration': 5,
      });
    });

    test('initializes with values from SharedPreferences', () async {
      final container = ProviderContainer();
      
      // Riverpod Notifiers initialize lazily. Read it once to trigger build.
      container.read(settingsProvider);
      
      // Give it a moment to complete _init()
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(settingsProvider);
      
      expect(state.loadBatchSize, 30);
      expect(state.syncInterval, 10);
      expect(state.cooldownDuration, 5);
      expect(state.syncBatchSize, 5); // Default
    });

    test('updates and persists values', () async {
      final container = ProviderContainer();
      container.read(settingsProvider);
      await Future.delayed(const Duration(milliseconds: 100));
      
      final notifier = container.read(settingsProvider.notifier);
      notifier.updateLoadBatchSize(50);
      
      final state = container.read(settingsProvider);
      expect(state.loadBatchSize, 50);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('loadBatchSize'), 50);
    });
  });
}
