import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:led_ble_lib/extension.dart';

import 'models/command_code.dart';
import 'models/led_screen.dart';
import 'models/program.dart';
import 'dart:developer' as developer;

/// TBD LED Bluetooth communication class
class LedBluetooth {
  /// Bluetooth service UUID
  static const String _serviceUuid = '0000a950-0000-1000-8000-00805f9b34fb';

  /// Write characteristic UUID (for data less than 20 bytes)
  static const String _writeSmallCharacteristicUuid = '0000a951-0000-1000-8000-00805f9b34fb';

  /// Write characteristic UUID (for large data)
  static const String _writeLargeCharacteristicUuid = '0000a952-0000-1000-8000-00805f9b34fb';

  /// Notification characteristic UUID
  static const String _notifyCharacteristicUuid = '0000a953-0000-1000-8000-00805f9b34fb';

  /// Advertisement name prefix
static const List<String> _advertisementNamePrefixes = ['iledcolor-', 'pix'];

  /// Advertisement filter name
  static const List<int> _advertisementFilterName = [0x54, 0x42, 0x44, 0x02];

  /// Identification code
  static const int _identificationCode = 0x54;

  /// Singleton instance
  static final LedBluetooth _instance = LedBluetooth._internal();

  /// Get singleton
  factory LedBluetooth() => _instance;

  /// Internal constructor
  LedBluetooth._internal();

  /// Currently connected device
  BluetoothDevice? _connectedDevice;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Write characteristic (small data)
  BluetoothCharacteristic? _writeSmallCharacteristic;

  /// Write characteristic (large data)
  BluetoothCharacteristic? _writeLargeCharacteristic;

  /// Notification characteristic
  BluetoothCharacteristic? _notifyCharacteristic;

  /// Device discovered stream controller
  final StreamController<LedScreen> _deviceDiscoveredController =
  StreamController<LedScreen>.broadcast();

  /// Connection state stream controller
  final StreamController<bool> _connectionStateController =
  StreamController<bool>.broadcast();

  /// Notification data stream controller
  final StreamController<List<int>> _notificationDataController =
  StreamController<List<int>>.broadcast();

  /// Device discovered stream
  Stream<LedScreen> get onDeviceDiscovered => _deviceDiscoveredController.stream;

  /// Connection state stream
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  /// Notification data stream
  Stream<List<int>> get onNotificationReceived => _notificationDataController.stream;

  /// Whether currently connected
  bool get isConnected => _connectedDevice != null;

  void logFullMessage(String message) {
    developer.log(message, name: 'LedBluetooth');
  }

  // Give iOS a bit more headroom when waiting for notify ACKs.
  Duration _ackTimeout() => Platform.isIOS
      ? const Duration(seconds: 2)
      : const Duration(seconds: 1);

  /// Initialize Bluetooth
  Future<bool> initialize() async {
    try {
      // Monitor Bluetooth state
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.off) {
          _connectionStateController.add(false);
        }
      });

      return true;
    } catch (e) {
      logFullMessage('Bluetooth initialization error: $e');
      return false;
    }
  }

  /// Scan for devices
  Future<void> startScan({Duration? timeout}) async {
    if (!await initialize()) {
      throw Exception('Bluetooth initialization failed');
    }

    // Stop previous scan before starting a new one
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    // Listen for scan results
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // Check device name and advertisement data
        if (_isLedDevice(result)) {
          try {
            // Parse advertisement data
            LedScreen ledScreen = _parseLedDevice(result);
            _deviceDiscoveredController.add(ledScreen);
          } catch (e) {
            logFullMessage('Error parsing device information: $e');
          }
        }
      }
    });

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 10),
      // withServices: [Guid(_serviceUuid)],
    );

    // If timeout specified, stop scanning after timeout
    if (timeout != null) {
      await Future.delayed(timeout);
      if (FlutterBluePlus.isScanningNow) {
        await stopScan();
        subscription.cancel();
      }
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // Disconnect previous connection
      if (_connectedDevice != null) {
        await disconnect();
      }

      // Connect to device
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find required characteristics
      for (BluetoothService service in services) {
        logFullMessage('service uuid: ${service.uuid.str128}');
        if (service.uuid.str128 == _serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String uuid = characteristic.uuid.str128;

            if (uuid == _writeSmallCharacteristicUuid) {
              _writeSmallCharacteristic = characteristic;
            } else if (uuid == _writeLargeCharacteristicUuid) {
              _writeLargeCharacteristic = characteristic;
            } else if (uuid == _notifyCharacteristicUuid) {
              _notifyCharacteristic = characteristic;

              // Subscribe to notifications
              await _notifyCharacteristic!.setNotifyValue(true);
              _notifyCharacteristic!.lastValueStream.listen((data) {
                _notificationDataController.add(data);
              });
            }
          }
        }
      }

      // Check if all required characteristics were found
      if (_writeSmallCharacteristic == null ||
          _writeLargeCharacteristic == null ||
          _notifyCharacteristic == null) {
        await disconnect();
        return false;
      }
      _connectionStateController.add(true);
      return true;
    } catch (e) {
      logFullMessage('Error connecting to device: $e');
      await disconnect();
      return false;
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        if (_notifyCharacteristic != null) {
          await _notifyCharacteristic!.setNotifyValue(false);
        }

        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _writeSmallCharacteristic = null;
        _writeLargeCharacteristic = null;
        _notifyCharacteristic = null;

        _connectionStateController.add(false);
      }
    } catch (e) {
      logFullMessage('Error disconnecting: $e');
    }
  }

  /// Check if it's an LED device
bool _isLedDevice(ScanResult result) {
  if (_advertisementNamePrefixes.any(result.device.platformName.startsWith)) {
    return true;
  }

    // Check advertisement data
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      for (var entry in result.advertisementData.manufacturerData.entries) {
        List<int> data = entry.value;
        if (data.length >= 4) {
          // Check filter name
          bool match = true;
          for (int i = 0; i < _advertisementFilterName.length; i++) {
            if (i >= data.length || data[i] != _advertisementFilterName[i]) {
              match = false;
              break;
            }
          }

          if (match) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Parse LED device information
  LedScreen _parseLedDevice(ScanResult result) {
    List<int>? manufacturerData;

    // Get manufacturer data
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      for (var entry in result.advertisementData.manufacturerData.entries) {
        List<int> data = entry.value;
        if (data.length >= 4) {
          // Check filter name
          bool match = true;
          for (int i = 0; i < _advertisementFilterName.length; i++) {
            if (i >= data.length || data[i] != _advertisementFilterName[i]) {
              match = false;
              break;
            }
          }

          if (match) {
            manufacturerData = data;
            break;
          }
        }
      }
    }


    // If manufacturer data not found, use default values
    manufacturerData ??= [
        0x01, // Product type
        ..._advertisementFilterName, // Filter name 54 42 44 02
        0x00, 0x0C, // Screen height (12)
        0x00, 0x30, // Screen width (48)
        0x01, // Screen color type (monochrome)
        0x00, // Screen rotation angle (0°)
        0x00, 0x01, // Firmware version (0.1)
        0x00, 0x00, // Customer ID
        0x00, // Product feature
        0x00, 0x00, // Reserved
      ];
    logFullMessage('manufacturerData: ${manufacturerData.toHex()}');

    return LedScreen.fromAdvertisement(
      manufacturerData,
      result.device.platformName,
      result.device.remoteId.str,
    );
  }

  /// Calculate checksum
  int _calculateChecksum(List<int> data) {
    int sum = 0;
    for (int value in data) {
      sum += value;
    }
    return sum & 0xFFFF; // Take the last 16 bits
  }

  /// Create command packet
  Uint8List _createCommandPacket(int commandCode, List<int> data) {
    // Calculate data length
    int dataLength = data.length + 2;

    // Create packet
    List<int> packet = [
      _identificationCode, // Identification code
      commandCode, // Command code
      (dataLength >> 8) & 0xFF, dataLength & 0xFF, // Data length
      ...data, // Data
    ];

    // Calculate checksum
    int checksum = _calculateChecksum(packet);
    packet.add((checksum >> 8) & 0xFF);
    packet.add(checksum & 0xFF);

    return Uint8List.fromList(packet);
  }

bool get _useWriteWithoutResponseSmall =>
    _writeSmallCharacteristic?.properties.writeWithoutResponse == true;

bool get _useWriteWithoutResponseLarge =>
    _writeLargeCharacteristic?.properties.writeWithoutResponse == true;

  /// Send small data command
  Future<bool> _sendSmallCommand(int commandCode, List<int> data) async {
    if (_connectedDevice == null || _writeSmallCharacteristic == null) {
      return false;
    }

    try {
      // Create command packet
      Uint8List packet = _createCommandPacket(commandCode, data);
      logFullMessage('_sendSmallCommand data: ${packet.toHex()}');

      // Send data
await _writeSmallCharacteristic!.write(
  packet,
  withoutResponse: _useWriteWithoutResponseSmall || Platform.isAndroid,
);


      return true;
    } catch (e) {
      logFullMessage('Error sending small data command: $e');
      return false;
    }
  }

  /// Send large data command
  Future<bool> _sendLargeCommand(int commandCode, List<int> data) async {
    if (_connectedDevice == null || _writeLargeCharacteristic == null) {
      return false;
    }
    logFullMessage('length: ${data.length}');

    try {
      // Packet size: Android can handle larger writes, iOS needs smaller chunks.
      final int maxPacketSize = Platform.isIOS ? 170 : 487;

      // Send in packets
      int totalPackets = (data.length / maxPacketSize).ceil();

      for (int i = 0; i < totalPackets; i++) {
        // Calculate current packet data range
        int start = i * maxPacketSize;
        int end = start + maxPacketSize;
        if (end > data.length) {
          end = data.length;
        }

        // Current packet data
        List<int> packetData = data.sublist(start, end);

        // Packet ID
        int packetId = i;

        final subPacketDataLen = packetData.length;

        // Create sub-packet data
        List<int> subPacketData = [
          // Packet ID (4 bytes)
          (packetId >> 24) & 0xFF,
          (packetId >> 16) & 0xFF,
          (packetId >> 8) & 0xFF,
          packetId & 0xFF,

          // Current packet data length (2 bytes)
          (subPacketDataLen >> 8) & 0xFF,
          subPacketDataLen & 0xFF,

          // Current packet data
          ...packetData,
        ];

        // Create command packet
        Uint8List packet = _createCommandPacket(commandCode, subPacketData);
        logFullMessage('packet: $packet');

        // Prepare to wait for response BEFORE writing (avoid race)
        Completer<bool> completer = Completer<bool>();
        StreamSubscription? subscription;
        subscription = _notificationDataController.stream.listen((data) {
          // Check if response matches packet ID
          logFullMessage('_notificationDataController data: ${data.toHex()}');
          if (data.length >= 9 &&
              data[0] == _identificationCode &&
              data[1] == commandCode) {
            // Check packet ID
            int responsePacketId = (data[4] << 24) |
                (data[5] << 16) |
                (data[6] << 8) |
                data[7];
            logFullMessage('responsePacketId: $responsePacketId');
            if (responsePacketId == packetId) {
              // Check response status
              bool success = data[8] == 0x01;
              subscription?.cancel();
              logFullMessage('success: $success');
              completer.complete(success);
            }
          }
        });

        // Send data
await _writeLargeCharacteristic!.write(
  packet,
  withoutResponse: _useWriteWithoutResponseLarge || Platform.isAndroid,
);
if (Platform.isIOS) {
  await Future.delayed(const Duration(milliseconds: 8));
}




        // Set timeout
        Timer(_ackTimeout(), () {
          if (!completer.isCompleted) {
            subscription?.cancel();
            completer.complete(false);
          }
        });

        // Wait for response result
        bool success = await completer.future;
        if (!success) {
          // If failed, retry 3 times
          int retryCount = 0;
          while (!success && retryCount < 3) {
            retryCount++;
            success = await _sendPacketWithResponse(commandCode, subPacketData);
          }

          if (!success) {
            return false;
          }
        }
      }

      // Send completion notification
      List<int> completionData = [0x01];
      Uint8List packet = _createCommandPacket(
          CommandCode.sendCompletionNotification, completionData);
      logFullMessage('_sendLargeCommand data: ${packet.toHex()}');

      // Prepare listener before writing
      Completer<bool> completer = Completer<bool>();
      StreamSubscription? subscription;
      subscription = _notificationDataController.stream.listen((data) {
        logFullMessage('_notificationDataController data: ${data.toHex()}');
        subscription?.cancel();
        completer.complete(true);
      });

      await _writeLargeCharacteristic!.write(
        packet,
        withoutResponse: _useWriteWithoutResponseLarge || Platform.isAndroid,
      );
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 8));
      }


      // Set timeout
      Timer(_ackTimeout(), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(false);
        }
      });

      // Wait for response result
      bool success = await completer.future;
      return success;
    } catch (e) {
      logFullMessage('Error sending large data command: $e');
      return false;
    }
  }

  /// Send packet and wait for response
  Future<bool> _sendPacketWithResponse(int commandCode, List<int> data) async {
    // Wait for response
    Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;

    subscription = _notificationDataController.stream.listen((response) {
      // Check if response matches
      if (response.length >= 5 &&
          response[0] == _identificationCode &&
          response[1] == commandCode) {

        // Check response status
        bool success = response[4] == 0x01;
        subscription?.cancel();
        completer.complete(success);
      }
    });

    // Create command packet and send after listener is ready
    Uint8List packet = _createCommandPacket(commandCode, data);
await _writeLargeCharacteristic!.write(
  packet,
  withoutResponse: _useWriteWithoutResponseLarge || Platform.isAndroid,
);
if (Platform.isIOS) {
  await Future.delayed(const Duration(milliseconds: 8));
}

    // Set timeout
    Timer(_ackTimeout(), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });

    return await completer.future;
  }

  /// Delete all programs
  Future<bool> deleteAllPrograms() async {
    Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;
    subscription = _notificationDataController.stream.listen((data) {
      if (data.length >= 5 &&
          data[0] == _identificationCode &&
          data[1] == CommandCode.deleteAllPrograms) {

        int result = data[4];
        logFullMessage('deleteAllPrograms result: $result');
        subscription?.cancel();
        completer.complete(result == 1);
      }
    });

    await _sendSmallCommand(CommandCode.deleteAllPrograms, [0x00]);

    // Set timeout
    Timer(_ackTimeout(), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });
    return await completer.future;
  }

  /// Add program to playlist
  Future<bool> addProgramToPlaylist(Program program, {
    required int programCount,
    required int programNumber,
    required int playbackCount,
    required int circularBorder,
  }) async {
    if (_connectedDevice == null) {
      return false;
    }

    try {
      // Create add program command data
      List<int> commandData = [
        programCount, // Total number of programs in playlist
        programNumber, // Program number

        // Program ID
        (program.programId >> 24) & 0xFF,
        (program.programId >> 16) & 0xFF,
        (program.programId >> 8) & 0xFF,
        program.programId & 0xFF,

        // Program data total length
        (program.programData.length >> 24) & 0xFF,
        (program.programData.length >> 16) & 0xFF,
        (program.programData.length >> 8) & 0xFF,
        program.programData.length & 0xFF,

        playbackCount, // Playback count
        circularBorder, // Circular border
        0x00, 0x00, // Reserved bytes
      ];

      // Wait for response (subscribe BEFORE sending command)
      Completer<bool> completer = Completer<bool>();
      StreamSubscription? subscription;
      subscription = _notificationDataController.stream.listen((data) {
        if (data.length >= 5 &&
            data[0] == _identificationCode &&
            data[1] == CommandCode.addProgramToPlaylist) {

          int result = data[4];
          logFullMessage('addProgramToPlaylist result: $result');
          subscription?.cancel();
          completer.complete(result == 1);
        }
      });

      // Send add program command
      await _sendSmallCommand(
        CommandCode.addProgramToPlaylist,
        commandData,
      );

      // Set timeout
      Timer(_ackTimeout(), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(false);
        }
      });


      if (!await completer.future) {
        return false;
      }

      // Send program data
      return await _sendLargeCommand(
        CommandCode.sendProgramData,
        program.toBytes(),
      );
    } catch (e) {
      logFullMessage('Error adding program to playlist: $e');
      return false;
    }
  }

  /// Complete updating program playlist
  Future<bool> updatePlaylistComplete() async {
    // Wait for response
    Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;

    subscription = _notificationDataController.stream.listen((data) {
      if (data.length >= 5 &&
          data[0] == _identificationCode &&
          data[1] == CommandCode.updatePlaylistComplete) {

        int result = data[4];
        logFullMessage('updatePlaylistComplete result: $result');
        subscription?.cancel();
        completer.complete(result == 1);
      }
    });

    await _sendSmallCommand(CommandCode.updatePlaylistComplete, [0x01]);

    // Set timeout
    Timer(_ackTimeout(), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });
    return await completer.future;
  }

  /// Send music and microphone rhythm
  Future<bool> sendMusicRhythm(bool enable, List<int> rhythmData) async {
    List<int> commandData = [
      enable ? 0x01 : 0x00, // Rhythm status
      ...rhythmData, // Rhythm data
    ];

    return await _sendLargeCommand(CommandCode.sendMusicRhythm, commandData);
  }

  /// Send real-time doodle data
  Future<bool> sendDoodleData({
    required int mode,
    required int type,
    required int row,
    required int column,
    required List<int> colorData,
  }) async {
    List<int> commandData = [
      mode, // Doodle mode
      type, // Type
      row, // Row number
      column, // Column number
      ...colorData, // Color data
    ];

    return await _sendSmallCommand(CommandCode.sendDoodleData, commandData);
  }

  /// Send temporary program
  Future<bool> sendTemporaryProgram(Program program, {required int circularBorder}) async {
    if (_connectedDevice == null) {
      return false;
    }

    try {
      // Create temporary program command data
      List<int> commandData = [
        // Program ID
        (program.programId >> 24) & 0xFF,
        (program.programId >> 16) & 0xFF,
        (program.programId >> 8) & 0xFF,
        program.programId & 0xFF,

        // Program data total length
        (program.programData.length >> 24) & 0xFF,
        (program.programData.length >> 16) & 0xFF,
        (program.programData.length >> 8) & 0xFF,
        program.programData.length & 0xFF,

        circularBorder, // Circular border
        0x00, 0x00, // Reserved bytes
      ];

      // Wait for response (subscribe before command)
      Completer<bool> completer = Completer<bool>();
      StreamSubscription? subscription;
      subscription = _notificationDataController.stream.listen((response) {
        logFullMessage('response: ${response.toHex()}');
        // Check if response matches
        if (response.length >= 5 &&
            response[0] == _identificationCode &&
            response[1] == CommandCode.sendTemporaryProgram) {

          // Check response status
          bool success = response[4] == 0x01;
          subscription?.cancel();
          completer.complete(success);
        }
      });

      // Send temporary program command
      await _sendSmallCommand(
        CommandCode.sendTemporaryProgram,
        commandData,
      );

      // Set timeout
      Timer(_ackTimeout(), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(false);
        }
      });

      if (!await completer.future) {
        return false;
      }

      // Send program data
      return await _sendLargeCommand(
        CommandCode.sendProgramData,
        program.toBytes(),
      );
    } catch (e) {
      logFullMessage('Error sending temporary program: $e');
      return false;
    }
  }

  /// Select program
  Future<bool> selectProgram({
    required int mode,
    int programNumber = 0,
  }) async {
    List<int> commandData = [
      mode, // Mode
      (programNumber >> 8) & 0xFF, // Program number high byte
      programNumber & 0xFF, // Program number low byte
      0x00, 0x00, 0x00, 0x00, // Reserved bytes
    ];

    // Wait for response
    Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;

    subscription = _notificationDataController.stream.listen((data) {
      if (data.length >= 5 &&
          data[0] == _identificationCode &&
          data[1] == CommandCode.selectProgram) {

        int result = data[4];
        logFullMessage('selectProgram result: $result');
        subscription?.cancel();
        completer.complete(result == 1);
      }
    });

    await _sendSmallCommand(CommandCode.selectProgram, commandData);

    // Set timeout
    Timer(_ackTimeout(), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });
    return await completer.future;
  }

  /// Set LED screen brightness
  Future<bool> setBrightness(Brightness brightness) async {
    List<int> commandData = [
      brightness.value, // Brightness value
      0x00, // Reserved byte
    ];

    return await _sendSmallCommand(CommandCode.setBrightness, commandData);
  }

  /// Switch LED screen
  Future<bool> switchLedScreen(bool on) async {
    List<int> commandData = [
      on ? 0x01 : 0x00, // Screen status
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Reserved bytes
    ];

    return await _sendSmallCommand(CommandCode.switchLedScreen, commandData);
  }
  
//       Future<void> setRotation(int angle) async {
//     if (_writeSmallCharacteristic == null) {
//       throw Exception('Write characteristic not initialized');
//     }
//      if (angle < 0 || angle > 3) {
//     throw ArgumentError('Rotation angle must be 0 (0°), 1 (90°), 2 (180°), or 3 (270°)');
//   }
//     // Construct the packet according to the protocol
//     final data = <int>[
//       _identificationCode, // IC = 0x54
//       CommandCode.setRotation, // 0x0B
//       0x00, 0x03, // DL = 3 bytes
//       angle, // rotation angle value
//       0x00, 0x00, // Placeholder for checksum
//     ];

//     // Calculate checksum (last 2 bytes are sum of previous bytes & 0xFFFF)
//     final checksum = data.take(data.length - 2).reduce((a, b) => a + b) & 0xFFFF;
// data[data.length - 2] = checksum & 0xFF;       // بایت کم
// data[data.length - 1] = (checksum >> 8) & 0xFF; // بایت زیاد


//     // Send the data over BLE
//     await _writeSmallCharacteristic!.write(Uint8List.fromList(data), withoutResponse: false);
//   }

  /// Set LED screen rotation angle
  Future<bool> setRotation(ScreenRotation rotation) async {
    List<int> commandData = [
      rotation.value, // Rotation angle
    ];

    return await _sendSmallCommand(CommandCode.setRotation, commandData);
  }

  /// Correct LED screen time
  Future<bool> correctTime(DateTime dateTime) async {
    List<int> commandData = [
      (dateTime.year >> 8) & 0xFF, // Year high byte
      dateTime.year & 0xFF, // Year low byte
      dateTime.month, // Month
      dateTime.day, // Day
      dateTime.hour, // Hour
      dateTime.minute, // Minute
      dateTime.second, // Second
      0x00, 0x00, // Reserved bytes
    ];

    return await _sendSmallCommand(CommandCode.correctTime, commandData);
  }

  /// Get total number of built-in GIFs
  Future<int> getBuiltInGifCount() async {
    if (_connectedDevice == null) {
      return 0;
    }

    try {
      // Wait for response (subscribe before command)
      Completer<int> completer = Completer<int>();
      StreamSubscription? subscription;
      subscription = _notificationDataController.stream.listen((data) {
        if (data.length >= 5 &&
            data[0] == _identificationCode &&
            data[1] == CommandCode.getBuiltInGifCount) {

          int count = data[4];
          subscription?.cancel();
          completer.complete(count);
        }
      });

      // Send get built-in GIF count command
      bool success = await _sendSmallCommand(
        CommandCode.getBuiltInGifCount,
        [0x00],
      );

      if (!success) {
        subscription.cancel();
        return 0;
      }

      // Set timeout
      Timer(_ackTimeout(), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(0);
        }
      });

      return await completer.future;
    } catch (e) {
      logFullMessage('Error getting built-in GIF count: $e');
      return 0;
    }
  }

  /// Set password
  Future<bool> setPassword({
    required int mode,
    required List<int> oldPassword,
    List<int>? newPassword,
  }) async {
    List<int> commandData = [
      mode, // Mode
      ...oldPassword, // Old password
      ...(newPassword ?? [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), // New password
    ];

    return await _sendSmallCommand(CommandCode.setPassword, commandData);
  }

  /// Verify password
  Future<bool> verifyPassword(List<int> password) async {
    List<int> commandData = [
      ...password, // Password
    ];

    return await _sendSmallCommand(CommandCode.verifyPassword, commandData);
  }

  /// Query if firmware supports new features
  Future<bool> queryFeatureSupport(int featureCode) async {
    if (_connectedDevice == null) {
      return false;
    }

    try {
      // Send query command
      List<int> commandData = [
        featureCode, // Feature code
      ];

      // Wait for response (subscribe before command)
      Completer<bool> completer = Completer<bool>();
      StreamSubscription? subscription;
      subscription = _notificationDataController.stream.listen((data) {
        if (data.length >= 5 &&
            data[0] == _identificationCode &&
            data[1] == CommandCode.queryFeatureSupport) {

          bool supported = data[4] == 0x01;
          subscription?.cancel();
          completer.complete(supported);
        }
      });

      bool success = await _sendSmallCommand(
        CommandCode.queryFeatureSupport,
        commandData,
      );

      if (!success) {
        subscription.cancel();
        return false;
      }

      // Set timeout
      Timer(_ackTimeout(), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      logFullMessage('Error querying feature support: $e');
      return false;
    }
  }

  /// Release resources
  void dispose() {
    _deviceDiscoveredController.close();
    _connectionStateController.close();
    _notificationDataController.close();

    disconnect();
  }
}
