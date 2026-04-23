import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, oldest, random, trending }
enum MediaFilter { video, image, text }

class SettingsState {
  final FeedSort sort;
  final Set<MediaFilter> filters;
  final bool autoplay;
  final bool isListView;
  final int mediaCacheSizeMB;
  
  // New architectural parameters
  final int syncInterval;
  final int syncBatchSize;
  final int loadBatchSize;
  final int cooldownDuration;
  final int pruneThreshold;

  SettingsState({
    this.sort = FeedSort.latest,
    this.filters = const {},
    this.autoplay = true,
    this.isListView = false,
    this.mediaCacheSizeMB = 500,
    this.syncInterval = 15,
    this.syncBatchSize = 5,
    this.loadBatchSize = 20,
    this.cooldownDuration = 15,
    this.pruneThreshold = 50000,
  });

  SettingsState copyWith({
    FeedSort? sort,
    Set<MediaFilter>? filters,
    bool? autoplay,
    bool? isListView,
    int? mediaCacheSizeMB,
    int? syncInterval,
    int? syncBatchSize,
    int? loadBatchSize,
    int? cooldownDuration,
    int? pruneThreshold,
  }) {
    return SettingsState(
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      autoplay: autoplay ?? this.autoplay,
      isListView: isListView ?? this.isListView,
      mediaCacheSizeMB: mediaCacheSizeMB ?? this.mediaCacheSizeMB,
      syncInterval: syncInterval ?? this.syncInterval,
      syncBatchSize: syncBatchSize ?? this.syncBatchSize,
      loadBatchSize: loadBatchSize ?? this.loadBatchSize,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      pruneThreshold: pruneThreshold ?? this.pruneThreshold,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _init();
    return SettingsState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final sortIdx = _prefs.getInt('sort') ?? 0;
    final filterStrings = _prefs.getStringList('filters') ?? [];
    
    final filters = filterStrings
        .map((s) {
          try {
            return MediaFilter.values.firstWhere((f) => f.name == s);
          } catch (_) {
            return null;
          }
        })
        .whereType<MediaFilter>()
        .toSet();

    final isListView = _prefs.getBool('isListView') ?? false;
    final mediaCacheSizeMB = _prefs.getInt('mediaCacheSizeMB') ?? 500;
    
    final syncInterval = _prefs.getInt('syncInterval') ?? 15;
    final syncBatchSize = _prefs.getInt('syncBatchSize') ?? 5;
    final loadBatchSize = _prefs.getInt('loadBatchSize') ?? 20;
    final cooldownDuration = _prefs.getInt('cooldownDuration') ?? 15;
    final pruneThreshold = _prefs.getInt('pruneThreshold') ?? 50000;

    state = SettingsState(
      sort: sortIdx < FeedSort.values.length ? FeedSort.values[sortIdx] : FeedSort.latest,
      filters: filters,
      autoplay: _prefs.getBool('autoplay') ?? true,
      isListView: isListView,
      mediaCacheSizeMB: mediaCacheSizeMB,
      syncInterval: syncInterval,
      syncBatchSize: syncBatchSize,
      loadBatchSize: loadBatchSize,
      cooldownDuration: cooldownDuration,
      pruneThreshold: pruneThreshold,
    );
  }

  void updateSort(FeedSort sort) {
    state = state.copyWith(sort: sort);
    _prefs.setInt('sort', sort.index);
  }

  void updateMediaCacheSize(int megabytes) {
    state = state.copyWith(mediaCacheSizeMB: megabytes);
    _prefs.setInt('mediaCacheSizeMB', megabytes);
  }

  void updateSyncInterval(int minutes) {
    state = state.copyWith(syncInterval: minutes);
    _prefs.setInt('syncInterval', minutes);
  }

  void updateSyncBatchSize(int size) {
    state = state.copyWith(syncBatchSize: size);
    _prefs.setInt('syncBatchSize', size);
  }

  void updateLoadBatchSize(int size) {
    state = state.copyWith(loadBatchSize: size);
    _prefs.setInt('loadBatchSize', size);
  }

  void updateCooldownDuration(int minutes) {
    state = state.copyWith(cooldownDuration: minutes);
    _prefs.setInt('cooldownDuration', minutes);
  }

  void updatePruneThreshold(int count) {
    state = state.copyWith(pruneThreshold: count);
    _prefs.setInt('pruneThreshold', count);
  }

  void toggleFilter(MediaFilter filter) {
    final nextFilters = Set<MediaFilter>.from(state.filters);
    if (nextFilters.contains(filter)) {
      nextFilters.remove(filter);
    } else {
      nextFilters.add(filter);
    }
    state = state.copyWith(filters: nextFilters);
    _prefs.setStringList('filters', nextFilters.map((f) => f.name).toList());
  }

  void toggleAutoplay(bool value) {
    state = state.copyWith(autoplay: value);
    _prefs.setBool('autoplay', value);
  }

  void toggleListView(bool value) {
    state = state.copyWith(isListView: value);
    _prefs.setBool('isListView', value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
