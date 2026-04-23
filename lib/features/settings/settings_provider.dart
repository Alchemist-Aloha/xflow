import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, oldest, random, trending }
enum MediaFilter { video, image, text }

class SettingsState {
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

  // New Discovery Algorithm parameters
  final bool avoidWatchedContent;
  final bool unseenSubscriptionBoost;
  final double freshMixRatio;
  final int saturationThreshold;
  final FeedSort fetchStrategy;
  final int initialSyncCount;

  SettingsState({
    this.filters = const {},
    this.autoplay = true,
    this.isListView = false,
    this.mediaCacheSizeMB = 500,
    this.syncInterval = 15,
    this.syncBatchSize = 5,
    this.loadBatchSize = 20,
    this.cooldownDuration = 15,
    this.pruneThreshold = 50000,
    this.avoidWatchedContent = true,
    this.unseenSubscriptionBoost = true,
    this.freshMixRatio = 0.3,
    this.saturationThreshold = 2,
    this.fetchStrategy = FeedSort.latest,
    this.initialSyncCount = 10,
  });

  SettingsState copyWith({
    Set<MediaFilter>? filters,
    bool? autoplay,
    bool? isListView,
    int? mediaCacheSizeMB,
    int? syncInterval,
    int? syncBatchSize,
    int? loadBatchSize,
    int? cooldownDuration,
    int? pruneThreshold,
    bool? avoidWatchedContent,
    bool? unseenSubscriptionBoost,
    double? freshMixRatio,
    int? saturationThreshold,
    FeedSort? fetchStrategy,
    int? initialSyncCount,
  }) {
    return SettingsState(
      filters: filters ?? this.filters,
      autoplay: autoplay ?? this.autoplay,
      isListView: isListView ?? this.isListView,
      mediaCacheSizeMB: mediaCacheSizeMB ?? this.mediaCacheSizeMB,
      syncInterval: syncInterval ?? this.syncInterval,
      syncBatchSize: syncBatchSize ?? this.syncBatchSize,
      loadBatchSize: loadBatchSize ?? this.loadBatchSize,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      pruneThreshold: pruneThreshold ?? this.pruneThreshold,
      avoidWatchedContent: avoidWatchedContent ?? this.avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost ?? this.unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio ?? this.freshMixRatio,
      saturationThreshold: saturationThreshold ?? this.saturationThreshold,
      fetchStrategy: fetchStrategy ?? this.fetchStrategy,
      initialSyncCount: initialSyncCount ?? this.initialSyncCount,
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

    final avoidWatchedContent = _prefs.getBool('avoidWatchedContent') ?? true;
    final unseenSubscriptionBoost = _prefs.getBool('unseenSubscriptionBoost') ?? true;
    final freshMixRatio = _prefs.getDouble('freshMixRatio') ?? 0.3;
    final saturationThreshold = _prefs.getInt('saturationThreshold') ?? 2;
    final fetchStrategyIdx = _prefs.getInt('fetchStrategy') ?? 0;
    final initialSyncCount = _prefs.getInt('initialSyncCount') ?? 10;

    state = SettingsState(
      filters: filters,
      autoplay: _prefs.getBool('autoplay') ?? true,
      isListView: isListView,
      mediaCacheSizeMB: mediaCacheSizeMB,
      syncInterval: syncInterval,
      syncBatchSize: syncBatchSize,
      loadBatchSize: loadBatchSize,
      cooldownDuration: cooldownDuration,
      pruneThreshold: pruneThreshold,
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      fetchStrategy: fetchStrategyIdx < FeedSort.values.length ? FeedSort.values[fetchStrategyIdx] : FeedSort.latest,
      initialSyncCount: initialSyncCount,
    );
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

  void updateDiscoveryParam({
    bool? avoidWatchedContent,
    bool? unseenSubscriptionBoost,
    double? freshMixRatio,
    int? saturationThreshold,
    FeedSort? fetchStrategy,
    int? initialSyncCount,
  }) {
    state = state.copyWith(
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      fetchStrategy: fetchStrategy,
      initialSyncCount: initialSyncCount,
    );
    if (avoidWatchedContent != null) _prefs.setBool('avoidWatchedContent', avoidWatchedContent);
    if (unseenSubscriptionBoost != null) _prefs.setBool('unseenSubscriptionBoost', unseenSubscriptionBoost);
    if (freshMixRatio != null) _prefs.setDouble('freshMixRatio', freshMixRatio);
    if (saturationThreshold != null) _prefs.setInt('saturationThreshold', saturationThreshold);
    if (fetchStrategy != null) _prefs.setInt('fetchStrategy', fetchStrategy.index);
    if (initialSyncCount != null) _prefs.setInt('initialSyncCount', initialSyncCount);
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
