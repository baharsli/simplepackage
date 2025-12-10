import 'package:flutter/material.dart';
import 'dart:async';

// import 'package:pixply/Settings/color_encoder.dart';

typedef OnColorChangedCallback = void Function(Color color);

class ColorConfig {
  static Color selectedDisplayColor = Colors.white; // Default white
  static double ledMasterBrightness = 1.0;      // 0..1
  static final List<OnColorChangedCallback> _callbacks = [];
  static Timer? _debounceTimer;
  static const int _debounceMs = 180; 

  static void addListener(OnColorChangedCallback callback) {
    if (!_callbacks.contains(callback)) {
      _callbacks.add(callback);
    }
  }

  static void removeListener(OnColorChangedCallback callback) {
    _callbacks.remove(callback);
  }
  // static ScreenRotation selectedRotation = ScreenRotation.degree0;
  // static OnColorChangedCallback? onColorChanged;

  static void setColor(Color color) {
    if (color == selectedDisplayColor) return;

    selectedDisplayColor = color;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      final callbacks = List<OnColorChangedCallback>.from(_callbacks);
      for (final cb in callbacks) {
        cb(selectedDisplayColor);
      }
      _debounceTimer = null;
    });
  }
}
