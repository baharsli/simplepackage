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
    selectedDisplayColor = color;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      for (final callback in List.of(_callbacks)) {
        callback(selectedDisplayColor);
      }
    });
    /// Helper to get 3 raw bytes ready for LED


    // Auto-refresh the content
    // if (onColorChanged != null) {
    //   onColorChanged!(color);
    // }
  }
}

