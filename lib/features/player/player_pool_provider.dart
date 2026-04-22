import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerInstance {
  final Player player;
  final VideoController controller;

  PlayerInstance(this.player, this.controller);

  void dispose() {
    player.dispose();
  }
}

class PlayerPoolNotifier extends Notifier<Map<String, PlayerInstance>> {
  @override
  Map<String, PlayerInstance> build() {
    ref.onDispose(() {
      for (final instance in state.values) {
        instance.dispose();
      }
    });
    return {};
  }

  void warmup(String id, String url) {
    if (state.containsKey(id)) return;

    final player = Player();
    final controller = VideoController(player);
    player.open(Media(url), play: false); // Pre-load but don't play
    
    state = {...state, id: PlayerInstance(player, controller)};
  }

  void cleanupExcept(Set<String> activeIds) {
    final newState = <String, PlayerInstance>{};
    for (final entry in state.entries) {
      if (activeIds.contains(entry.key)) {
        newState[entry.key] = entry.value;
      } else {
        entry.value.dispose();
      }
    }
    state = newState;
  }
}

final playerPoolProvider = NotifierProvider<PlayerPoolNotifier, Map<String, PlayerInstance>>(
  PlayerPoolNotifier.new,
);
