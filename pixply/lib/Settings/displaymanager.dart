import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:pixply/Settings/color_config.dart';
import 'package:pixply/Settings/rotation_config.dart';

/// Constants for LED panel dimensions
int ledWidth = 56;
int ledHeight = 56;

/// Types of content we can display
enum DisplayType { image, text, gif }

/// Central manager for tracking and refreshing display content
class DisplayManager {
  static LedBluetooth? _bluetooth;
  static String? _lastPath;
  static DisplayType? _lastType;
  static bool _initialized = false;
  static bool _refreshInFlight = false;
  static bool _forceClearPlaylist = false;
  static bool _pending = false;

  static ScreenRotation? _lastAppliedRotation;

  /// Call this once after Bluetooth is initialized
  static void initialize(LedBluetooth bluetooth) {
    _bluetooth = bluetooth;
    if (_initialized) return;
    _initialized = true;
    ColorConfig.addListener(_onColorChanged);
    RotationStore.addListener(_onRotationChanged);
    _lastAppliedRotation = RotationStore.selectedRotation;
  }

  /// Call this every time new content is displayed (image/text/gif)
  static void recordLastDisplay({
    required String path,
    required DisplayType type,
  }) {
    _lastPath = path;
    _lastType = type;
  }

  /// Automatically called when color changes
  static Future<void> _onColorChanged(Color newColor) async {
    if (_bluetooth == null || !_bluetooth!.isConnected || _lastPath == null) return;

    _pending = true;
    // Debounce already handled in ColorConfig; trigger refresh immediately in next microtask.
    scheduleMicrotask(_drainRefresh);
  }

  static Future<void> _onRotationChanged(ScreenRotation newRotation) async {
    if (_bluetooth == null || !_bluetooth!.isConnected || _lastPath == null) return;
    _pending = true;
    await _drainRefresh();
  }

  static Future<void> _drainRefresh() async {
    if (_refreshInFlight) {
      _pending = true;
      return;
    }
    _refreshInFlight = true;
    try {
      while (_pending) {
        _pending = false;
        await _refreshDisplay();
      }
    } finally {
      _refreshInFlight = false;
      if (_pending) {
        scheduleMicrotask(_drainRefresh);
      }
    }
  }

  /// External refresh entrypoint. If [clearBeforeSend] is true, force clear playlist before sending.
  static Future<void> refreshDisplay({bool clearBeforeSend = false}) {
    if (clearBeforeSend) _forceClearPlaylist = true;
    _pending = true;
    return _drainRefresh();
  }

  static Future<void> _refreshDisplay() async {
    if (_bluetooth == null || !_bluetooth!.isConnected || _lastPath == null) return;

    final bool forceClear = _forceClearPlaylist;
    _forceClearPlaylist = false;
    final bool rotationChanged = _lastAppliedRotation != RotationStore.selectedRotation;
    _lastAppliedRotation = RotationStore.selectedRotation;

    // Power on, brightness, and rotation
    await _bluetooth!.switchLedScreen(true);
    final brightnessVal = ColorConfig.ledMasterBrightness;
    final Brightness level;
    if (brightnessVal < 0.33) {
      level = Brightness.minimum;
    } else if (brightnessVal < 0.66) {
      level = Brightness.medium;
    } else {
      level = Brightness.high;
    }
    await _bluetooth!.setBrightness(level);
    await _bluetooth!.setRotation(RotationStore.selectedRotation);

    // If rotation or content type changed, clear playlist to rebuild cleanly
    final bool structuralChange = rotationChanged || _lastType != DisplayType.image;
    final bool cleared = forceClear || structuralChange;
    if (cleared) {
      await _bluetooth!.deleteAllPrograms();
      await _bluetooth!.updatePlaylistComplete();
    }

    switch (_lastType) {
      case DisplayType.image:
        await _sendColoredImage(_lastPath!, cleared: cleared);
        break;
      default:
        break;
    }
  }

  /// Send the last image again with the new selected color
  static Future<void> _sendColoredImage(String path, {bool cleared = false}) async {
    final bmp = await _loadColoredBmp(path);
    final program = Program.bmp(
      bmpData: bmp,
      partitionX: 0,
      partitionY: 0,
      partitionWidth: ledWidth,
      partitionHeight: ledHeight,
      specialEffect: SpecialEffect.fixed,
      speed: 50,
      stayTime: 300000,
      circularBorder: 0,
      brightness: (ColorConfig.ledMasterBrightness * 100).clamp(0, 100).round(),
    );

    // Clear previous playlist only if it wasn't already cleared in _refreshDisplay.
    if (!cleared) {
      await _bluetooth!.deleteAllPrograms();
    }

    await _bluetooth!.addProgramToPlaylist(
      program,
      programCount: 1,
      programNumber: 0,
      playbackCount: 1,
      circularBorder: 0,
    );
    final ok = await _bluetooth!.updatePlaylistComplete();
    if (!ok) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _bluetooth!.updatePlaylistComplete();
    }
  }

  /// Apply current color to image using luminance logic
  static Future<Uint8List> _loadColoredBmp(String path) async {
    final ByteData data = await rootBundle.load(path);
    final img.Image? original = img.decodeImage(data.buffer.asUint8List());
    if (original == null) throw Exception('Image decode failed');

    final img.Image resized = img.copyResize(original, width: ledWidth, height: ledHeight);
    final img.Image rotated = _applyRotation(resized, RotationStore.selectedRotation);
    final List<int> buffer = [];
    final color = ColorConfig.selectedDisplayColor;

    final int r8 = color.red & 0xFF;
    final int g8 = color.green & 0xFF;
    final int b8 = color.blue & 0xFF;

    for (int y = 0; y < rotated.height; y++) {
      for (int x = 0; x < rotated.width; x++) {
        final pixel = rotated.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance > 128) {
          buffer.add(r8);
          buffer.add(g8);
          buffer.add(b8);
        } else {
          buffer.add(0);
          buffer.add(0);
          buffer.add(0);
        }
      }
    }

    return Uint8List.fromList(buffer);
  }

  /// Rotation logic for applying current display orientation
  static img.Image _applyRotation(img.Image image, ScreenRotation rotation) {
    switch (rotation) {
      case ScreenRotation.degree90:
        return img.copyRotate(image, angle: 90);
      case ScreenRotation.degree180:
        return img.copyRotate(image, angle: 180);
      case ScreenRotation.degree270:
        return img.copyRotate(image, angle: 270);
      case ScreenRotation.degree0:
        return image;
    }
  }
}
