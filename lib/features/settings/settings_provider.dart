import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, trending, algorithmic, chronological, videomixer }

enum MediaFilter { video, image, text }

enum VideoEndAction { pause, replay, playNext }

class SettingsState {
  final bool isInitialized;
  final Set<MediaFilter> filters;
  final bool autoplay;
  final bool isListView;
  final int mediaCacheSizeMB;

  // New architectural parameters
  final int syncInterval;
  final int syncBatchSize;
  final int loadBatchSize;
  final int timelineBatchSize;
  final int searchBatchSize;
  final int cooldownDuration;
  final int pruneThreshold;

  // New Discovery Algorithm parameters
  final bool avoidWatchedContent;
  final bool unseenSubscriptionBoost;
  final double freshMixRatio;
  final int saturationThreshold;
  final int mediaSaturationThreshold;
  final FeedSort fetchStrategy;
  final int initialSyncCount;
  final bool strictSubscriptionsOnly;
  final bool includeNativeRetweets;
  final bool useChunkedSubscriptions;
  final bool showDebugInfo;

  // Granular Discovery parameters
  final int saturationWindow;
  final int unseenBoostLookahead;
  final int minFavesFilter;

  // Advanced Tuning
  final int dbCandidateMultiplier;
  final int apiRetryLimit;
  final int chunkRotationLimit;
  final int pageRetryLimit;
  final int minNewTweetsThreshold;
  final int maxQueryLength;
  final int apiTimeoutSeconds;
  final int maxSaturationSwaps;
  final int maxSaturationPasses;

  // Playback & UI Tuning
  final int playbackRetryLimit;
  final int autoSkipDelaySeconds;
  final int lazyLoadThreshold;
  final int mediaDeduplicationWindow;
  final VideoEndAction videoEndAction;

  SettingsState({
    this.isInitialized = false,
    this.filters = const {},
    this.autoplay = true,
    this.isListView = false,
    this.mediaCacheSizeMB = 500,
    this.syncInterval = 15,
    this.syncBatchSize = 10,
    this.loadBatchSize = 20,
    this.timelineBatchSize = 20,
    this.searchBatchSize = 10,
    this.cooldownDuration = 15,
    this.pruneThreshold = 50000,
    this.avoidWatchedContent = true,
    this.unseenSubscriptionBoost = true,
    this.freshMixRatio = 0.3,
    this.saturationThreshold = 2,
    this.mediaSaturationThreshold = 1,
    this.fetchStrategy = FeedSort.chronological,
    this.initialSyncCount = 10,
    this.strictSubscriptionsOnly = true,
    this.includeNativeRetweets = false,
    this.useChunkedSubscriptions = true,
    this.showDebugInfo = false,
    this.saturationWindow = 10,
    this.unseenBoostLookahead = 6,
    this.minFavesFilter = 50,
    this.dbCandidateMultiplier = 5,
    this.apiRetryLimit = 5,
    this.chunkRotationLimit = 3,
    this.pageRetryLimit = 3,
    this.minNewTweetsThreshold = 5,
    this.maxQueryLength = 480,
    this.apiTimeoutSeconds = 15,
    this.maxSaturationSwaps = 1000,
    this.maxSaturationPasses = 3,
    this.playbackRetryLimit = 1,
    this.autoSkipDelaySeconds = 2,
    this.lazyLoadThreshold = 10,
    this.mediaDeduplicationWindow = 50,
    this.videoEndAction = VideoEndAction.playNext,
  });

  SettingsState copyWith({
    bool? isInitialized,
    Set<MediaFilter>? filters,
    bool? autoplay,
    bool? isListView,
    int? mediaCacheSizeMB,
    int? syncInterval,
    int? syncBatchSize,
    int? loadBatchSize,
    int? timelineBatchSize,
    int? searchBatchSize,
    int? cooldownDuration,
    int? pruneThreshold,
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
    bool? showDebugInfo,
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
    VideoEndAction? videoEndAction,
  }) {
    return SettingsState(
      isInitialized: isInitialized ?? this.isInitialized,
      filters: filters ?? this.filters,
      autoplay: autoplay ?? this.autoplay,
      isListView: isListView ?? this.isListView,
      mediaCacheSizeMB: mediaCacheSizeMB ?? this.mediaCacheSizeMB,
      syncInterval: syncInterval ?? this.syncInterval,
      syncBatchSize: syncBatchSize ?? this.syncBatchSize,
      loadBatchSize: loadBatchSize ?? this.loadBatchSize,
      timelineBatchSize: timelineBatchSize ?? this.timelineBatchSize,
      searchBatchSize: searchBatchSize ?? this.searchBatchSize,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      pruneThreshold: pruneThreshold ?? this.pruneThreshold,
      avoidWatchedContent: avoidWatchedContent ?? this.avoidWatchedContent,
      unseenSubscriptionBoost:
          unseenSubscriptionBoost ?? this.unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio ?? this.freshMixRatio,
      saturationThreshold: saturationThreshold ?? this.saturationThreshold,
      mediaSaturationThreshold:
          mediaSaturationThreshold ?? this.mediaSaturationThreshold,
      fetchStrategy: fetchStrategy ?? this.fetchStrategy,
      initialSyncCount: initialSyncCount ?? this.initialSyncCount,
      strictSubscriptionsOnly:
          strictSubscriptionsOnly ?? this.strictSubscriptionsOnly,
      includeNativeRetweets:
          includeNativeRetweets ?? this.includeNativeRetweets,
      useChunkedSubscriptions:
          useChunkedSubscriptions ?? this.useChunkedSubscriptions,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      saturationWindow: saturationWindow ?? this.saturationWindow,
      unseenBoostLookahead: unseenBoostLookahead ?? this.unseenBoostLookahead,
      minFavesFilter: minFavesFilter ?? this.minFavesFilter,
      dbCandidateMultiplier:
          dbCandidateMultiplier ?? this.dbCandidateMultiplier,
      apiRetryLimit: apiRetryLimit ?? this.apiRetryLimit,
      chunkRotationLimit: chunkRotationLimit ?? this.chunkRotationLimit,
      pageRetryLimit: pageRetryLimit ?? this.pageRetryLimit,
      minNewTweetsThreshold:
          minNewTweetsThreshold ?? this.minNewTweetsThreshold,
      maxQueryLength: maxQueryLength ?? this.maxQueryLength,
      apiTimeoutSeconds: apiTimeoutSeconds ?? this.apiTimeoutSeconds,
      maxSaturationSwaps: maxSaturationSwaps ?? this.maxSaturationSwaps,
      maxSaturationPasses: maxSaturationPasses ?? this.maxSaturationPasses,
      playbackRetryLimit: playbackRetryLimit ?? this.playbackRetryLimit,
      autoSkipDelaySeconds: autoSkipDelaySeconds ?? this.autoSkipDelaySeconds,
      lazyLoadThreshold: lazyLoadThreshold ?? this.lazyLoadThreshold,
      mediaDeduplicationWindow:
          mediaDeduplicationWindow ?? this.mediaDeduplicationWindow,
      videoEndAction: videoEndAction ?? this.videoEndAction,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _init();
    return SettingsState(isInitialized: false);
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
    final syncBatchSize = _prefs.getInt('syncBatchSize') ?? 10;
    final loadBatchSize = _prefs.getInt('loadBatchSize') ?? 20;
    final timelineBatchSize = _prefs.getInt('timelineBatchSize') ?? 20;
    final searchBatchSize = _prefs.getInt('searchBatchSize') ?? 10;
    final cooldownDuration = _prefs.getInt('cooldownDuration') ?? 15;
    final pruneThreshold = _prefs.getInt('pruneThreshold') ?? 50000;

    final avoidWatchedContent = _prefs.getBool('avoidWatchedContent') ?? true;
    final unseenSubscriptionBoost =
        _prefs.getBool('unseenSubscriptionBoost') ?? true;
    final freshMixRatio = _prefs.getDouble('freshMixRatio') ?? 0.3;
    final saturationThreshold = _prefs.getInt('saturationThreshold') ?? 2;
    final mediaSaturationThreshold =
        _prefs.getInt('mediaSaturationThreshold') ?? 1;
    final fetchStrategyIdx = _prefs.getInt('fetchStrategy') ?? 0;
    final initialSyncCount = _prefs.getInt('initialSyncCount') ?? 10;
    final strictSubscriptionsOnly =
        _prefs.getBool('strictSubscriptionsOnly') ?? true;
    final includeNativeRetweets =
        _prefs.getBool('includeNativeRetweets') ?? false;
    final useChunkedSubscriptions =
        _prefs.getBool('useChunkedSubscriptions') ?? true;
    final showDebugInfo = _prefs.getBool('showDebugInfo') ?? false;

    final saturationWindow = _prefs.getInt('saturationWindow') ?? 10;
    final unseenBoostLookahead = _prefs.getInt('unseenBoostLookahead') ?? 6;
    final minFavesFilter = _prefs.getInt('minFavesFilter') ?? 50;

    final dbCandidateMultiplier = _prefs.getInt('dbCandidateMultiplier') ?? 5;
    final apiRetryLimit = _prefs.getInt('apiRetryLimit') ?? 5;
    final chunkRotationLimit = _prefs.getInt('chunkRotationLimit') ?? 3;
    final pageRetryLimit = _prefs.getInt('pageRetryLimit') ?? 3;
    final minNewTweetsThreshold = _prefs.getInt('minNewTweetsThreshold') ?? 5;
    final maxQueryLength = _prefs.getInt('maxQueryLength') ?? 480;
    final apiTimeoutSeconds = _prefs.getInt('apiTimeoutSeconds') ?? 15;
    final maxSaturationSwaps = _prefs.getInt('maxSaturationSwaps') ?? 1000;
    final maxSaturationPasses = _prefs.getInt('maxSaturationPasses') ?? 3;
    final playbackRetryLimit = _prefs.getInt('playbackRetryLimit') ?? 1;
    final autoSkipDelaySeconds = _prefs.getInt('autoSkipDelaySeconds') ?? 2;
    final lazyLoadThreshold = _prefs.getInt('lazyLoadThreshold') ?? 10;
    final mediaDeduplicationWindow =
        _prefs.getInt('mediaDeduplicationWindow') ?? 50;
    final videoEndActionIdx = _prefs.getInt('videoEndAction') ?? VideoEndAction.playNext.index;

    state = SettingsState(
      isInitialized: true,
      filters: filters,
      autoplay: _prefs.getBool('autoplay') ?? true,
      isListView: isListView,
      mediaCacheSizeMB: mediaCacheSizeMB,
      syncInterval: syncInterval,
      syncBatchSize: syncBatchSize,
      loadBatchSize: loadBatchSize,
      timelineBatchSize: timelineBatchSize,
      searchBatchSize: searchBatchSize,
      cooldownDuration: cooldownDuration,
      pruneThreshold: pruneThreshold,
      avoidWatchedContent: avoidWatchedContent,
      unseenSubscriptionBoost: unseenSubscriptionBoost,
      freshMixRatio: freshMixRatio,
      saturationThreshold: saturationThreshold,
      mediaSaturationThreshold: mediaSaturationThreshold,
      fetchStrategy: fetchStrategyIdx < FeedSort.values.length
          ? FeedSort.values[fetchStrategyIdx]
          : FeedSort.latest,
      initialSyncCount: initialSyncCount,
      strictSubscriptionsOnly: strictSubscriptionsOnly,
      includeNativeRetweets: includeNativeRetweets,
      useChunkedSubscriptions: useChunkedSubscriptions,
      showDebugInfo: showDebugInfo,
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
      videoEndAction: videoEndActionIdx < VideoEndAction.values.length
          ? VideoEndAction.values[videoEndActionIdx]
          : VideoEndAction.playNext,
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

  void updateTimelineBatchSize(int size) {
    state = state.copyWith(timelineBatchSize: size);
    _prefs.setInt('timelineBatchSize', size);
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
    if (avoidWatchedContent != null)
      _prefs.setBool('avoidWatchedContent', avoidWatchedContent);
    if (unseenSubscriptionBoost != null)
      _prefs.setBool('unseenSubscriptionBoost', unseenSubscriptionBoost);
    if (freshMixRatio != null) _prefs.setDouble('freshMixRatio', freshMixRatio);
    if (saturationThreshold != null)
      _prefs.setInt('saturationThreshold', saturationThreshold);
    if (mediaSaturationThreshold != null)
      _prefs.setInt('mediaSaturationThreshold', mediaSaturationThreshold);
    if (fetchStrategy != null)
      _prefs.setInt('fetchStrategy', fetchStrategy.index);
    if (initialSyncCount != null)
      _prefs.setInt('initialSyncCount', initialSyncCount);
    if (strictSubscriptionsOnly != null)
      _prefs.setBool('strictSubscriptionsOnly', strictSubscriptionsOnly);
    if (includeNativeRetweets != null)
      _prefs.setBool('includeNativeRetweets', includeNativeRetweets);
    if (useChunkedSubscriptions != null)
      _prefs.setBool('useChunkedSubscriptions', useChunkedSubscriptions);
    if (saturationWindow != null)
      _prefs.setInt('saturationWindow', saturationWindow);
    if (unseenBoostLookahead != null)
      _prefs.setInt('unseenBoostLookahead', unseenBoostLookahead);
    if (minFavesFilter != null) _prefs.setInt('minFavesFilter', minFavesFilter);

    if (dbCandidateMultiplier != null)
      _prefs.setInt('dbCandidateMultiplier', dbCandidateMultiplier);
    if (apiRetryLimit != null) _prefs.setInt('apiRetryLimit', apiRetryLimit);
    if (chunkRotationLimit != null)
      _prefs.setInt('chunkRotationLimit', chunkRotationLimit);
    if (pageRetryLimit != null) _prefs.setInt('pageRetryLimit', pageRetryLimit);
    if (minNewTweetsThreshold != null)
      _prefs.setInt('minNewTweetsThreshold', minNewTweetsThreshold);
    if (maxQueryLength != null) _prefs.setInt('maxQueryLength', maxQueryLength);
    if (apiTimeoutSeconds != null)
      _prefs.setInt('apiTimeoutSeconds', apiTimeoutSeconds);
    if (maxSaturationSwaps != null)
      _prefs.setInt('maxSaturationSwaps', maxSaturationSwaps);
    if (maxSaturationPasses != null)
      _prefs.setInt('maxSaturationPasses', maxSaturationPasses);
    if (playbackRetryLimit != null)
      _prefs.setInt('playbackRetryLimit', playbackRetryLimit);
    if (autoSkipDelaySeconds != null)
      _prefs.setInt('autoSkipDelaySeconds', autoSkipDelaySeconds);
    if (lazyLoadThreshold != null)
      _prefs.setInt('lazyLoadThreshold', lazyLoadThreshold);
    if (mediaDeduplicationWindow != null)
      _prefs.setInt('mediaDeduplicationWindow', mediaDeduplicationWindow);
    if (searchBatchSize != null)
      _prefs.setInt('searchBatchSize', searchBatchSize);
    if (videoEndAction != null)
      _prefs.setInt('videoEndAction', videoEndAction.index);
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

  void toggleDebugInfo(bool value) {
    state = state.copyWith(showDebugInfo: value);
    _prefs.setBool('showDebugInfo', value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
