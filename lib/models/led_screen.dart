// ignore: unused_import
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// LED screen color type
enum LedColorType {
  /// Monochrome screen
  monochrome(0x00),

  /// Colorful
  colorful(0x01),

  /// Full color 1 (888)
  fullColor888(0x03),

  /// Full color 2 (565)
  fullColor565(0x04),

  /// Full color 3 (332)
  fullColor332(0x05);

  /// Color type value
  final int value;

  /// Constructor
  const LedColorType(this.value);

  /// Create color type from value
  static LedColorType fromValue(int value) {
    return LedColorType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => LedColorType.monochrome,
    );
  }
}

/// Screen rotation angle
enum ScreenRotation {
  /// 0 degrees
  degree0(0x00),

  /// 90 degrees
  degree90(0x01),

  /// 180 degrees
  degree180(0x02),

  /// 270 degrees
  degree270(0x03);

  /// Rotation angle value
  final int value;

  /// Constructor
  const ScreenRotation(this.value);

  /// Create rotation angle from value
  static ScreenRotation fromValue(int value) {
    return ScreenRotation.values.firstWhere(
          (rotation) => rotation.value == value,
      orElse: () => ScreenRotation.degree0,
    );
  }
}

/// LED screen brightness
enum Brightness {
  /// Minimum brightness
  minimum(0x03),

  /// Medium brightness
  medium(0x02),

  /// High brightness
  high(0x01);

  /// Brightness value
  final int value;

  /// Constructor
  const Brightness(this.value);

  /// Create brightness from value
  static Brightness fromValue(int value) {
    return Brightness.values.firstWhere(
          (brightness) => brightness.value == value,
      orElse: () => Brightness.medium,
    );
  }
}

/// LED screen information class
class LedScreen {
  /// Screen width
  final int width;

  /// Screen height
  final int height;

  /// Color type
  final LedColorType colorType;

  /// Rotation angle
  final ScreenRotation rotation;

  /// Firmware version
  final String firmwareVersion;

  /// Device MAC address
  final String macAddress;

  /// Device name
  final String name;

  /// Backing FlutterBlue device (used for connection)
  final BluetoothDevice device;

  /// Constructor
  const LedScreen({
    required this.width,
    required this.height,
    required this.colorType,
    required this.rotation,
    required this.firmwareVersion,
    required this.macAddress,
    required this.name,
    required this.device,
  });

  /// Create LED screen information from advertisement data
  factory LedScreen.fromAdvertisement(
    List<int> data,
    String deviceName,
    String deviceId,
    BluetoothDevice device,
  ) {
    // Check if advertisement data format is correct
    if (data.length < 14) {
      throw const FormatException('Invalid advertisement data format');
    }

    // Parse screen dimensions
    final height = (data[5] << 8) | data[6];
    final width = (data[7] << 8) | data[8];

    // Parse color type
    final colorType = LedColorType.fromValue(data[9]);

    // Parse rotation angle
    final rotation = ScreenRotation.fromValue(data[10]);

    // Parse firmware version
    final firmwareVersion = '${data[11]}.${data[12]}';

    // MAC address from device ID
    final macAddress = deviceId.toUpperCase();

    return LedScreen(
      width: width + 8,
      height: height + 44,
      colorType: colorType,
      rotation: rotation,
      firmwareVersion: firmwareVersion,
      macAddress: macAddress,
      name: deviceName,
      device: device,
    );
  }
}
