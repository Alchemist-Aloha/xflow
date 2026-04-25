import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLifecycle {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

class LifecycleNotifier extends StateNotifier<AppLifecycle> with WidgetsBindingObserver {
  LifecycleNotifier() : super(AppLifecycle.resumed) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        this.state = AppLifecycle.resumed;
        break;
      case AppLifecycleState.inactive:
        this.state = AppLifecycle.inactive;
        break;
      case AppLifecycleState.paused:
        this.state = AppLifecycle.paused;
        break;
      case AppLifecycleState.detached:
        this.state = AppLifecycle.detached;
        break;
      case AppLifecycleState.hidden:
        this.state = AppLifecycle.hidden;
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final lifecycleProvider = StateNotifierProvider<LifecycleNotifier, AppLifecycle>((ref) {
  return LifecycleNotifier();
});
