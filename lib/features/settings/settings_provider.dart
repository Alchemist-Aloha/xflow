import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedSort { latest, popular, oldest }
enum MediaFilter { all, videoOnly, imageOnly }

class SettingsState {
  final FeedSort sort;
  final MediaFilter filter;
  final bool autoplay;

  SettingsState({
    this.sort = FeedSort.latest,
    this.filter = MediaFilter.all,
    this.autoplay = true,
  });

  SettingsState copyWith({FeedSort? sort, MediaFilter? filter, bool? autoplay}) {
    return SettingsState(
      sort: sort ?? this.sort,
      filter: filter ?? this.filter,
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
    state = SettingsState(
      sort: FeedSort.values[_prefs.getInt('sort') ?? 0],
      filter: MediaFilter.values[_prefs.getInt('filter') ?? 0],
      autoplay: _prefs.getBool('autoplay') ?? true,
    );
  }

  void updateSort(FeedSort sort) {
    state = state.copyWith(sort: sort);
    _prefs.setInt('sort', sort.index);
  }

  void updateFilter(MediaFilter filter) {
    state = state.copyWith(filter: filter);
    _prefs.setInt('filter', filter.index);
  }

  void toggleAutoplay(bool value) {
    state = state.copyWith(autoplay: value);
    _prefs.setBool('autoplay', value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
