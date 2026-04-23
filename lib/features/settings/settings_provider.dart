import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, oldest, random, trending }
enum MediaFilter { video, image, gif, text }

class SettingsState {
  final FeedSort sort;
  final Set<MediaFilter> filters;
  final bool autoplay;

  SettingsState({
    this.sort = FeedSort.latest,
    this.filters = const {},
    this.autoplay = true,
  });

  SettingsState copyWith({FeedSort? sort, Set<MediaFilter>? filters, bool? autoplay}) {
    return SettingsState(
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      autoplay: autoplay ?? this.autoplay,
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

    state = SettingsState(
      sort: sortIdx < FeedSort.values.length ? FeedSort.values[sortIdx] : FeedSort.latest,
      filters: filters,
      autoplay: _prefs.getBool('autoplay') ?? true,
    );
  }

  void updateSort(FeedSort sort) {
    state = state.copyWith(sort: sort);
    _prefs.setInt('sort', sort.index);
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
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
