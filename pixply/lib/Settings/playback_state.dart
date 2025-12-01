import 'package:flutter/foundation.dart';

/// Broadcast-only store to notify UI widgets (Play buttons, etc.) that
/// playback has been cleared (e.g., after pressing Reset).
class PlaybackState {
  static final ValueNotifier<int> _resetEpoch = ValueNotifier<int>(0);

  static ValueListenable<int> get resetNotifier => _resetEpoch;

  static void notifyReset() {
    _resetEpoch.value++;
  }
}
