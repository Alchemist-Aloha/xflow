import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLifecycle {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

class LifecycleNotifier extends Notifier<AppLifecycle> with WidgetsBindingObserver {
  @override
  AppLifecycle build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    return AppLifecycle.resumed;
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


}

final lifecycleProvider = NotifierProvider<LifecycleNotifier, AppLifecycle>(
  LifecycleNotifier.new,
);
