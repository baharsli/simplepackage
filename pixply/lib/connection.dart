import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:pixply/games.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'text_data_lib.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:pixply/Likes/like_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'cannotfind.dart';
import 'package:pixply/showconnected.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pixply/core/activation.dart';
import 'package:flutter_svg/svg.dart';

// Painter for dotted line
class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  _DottedLinePainter({
    this.color = const Color(0xFF8B8B8B),
    this.strokeWidth = 1.0,
    this.dashWidth = 4.0,
    this.dashGap = 3.0,
  });
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ConnectionPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;

  const ConnectionPage(
      {super.key, required this.bluetooth, required this.isConnected});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  // BLE listeners to avoid accumulation across reopens
  StreamSubscription<LedScreen>? _discoverSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _connStateSub;
  // final LedBluetooth _bluetooth = LedBluetooth();
  late final LedBluetooth _bluetooth;
  final List<LedScreen> _discoveredDevices = [];
  final Map<String, BluetoothDevice> _deviceCache = {};
  LedScreen? _selectedDevice;
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  int ledWidth = 56;
  int ledHeight = 56;
  bool _navigatedToConnected = false;
  static const String _kLastMacKey = 'last_pixmat_mac';
  bool _activationPromptShown = false;
  // Separate webhook for "enter games without board" activation flow
  static const String _kNoBoardWebhookUrl =
      'https://hook.eu2.make.com/hnc3ft64r28svcdmfo7qpxqnk2p8ikyg';
  // Long-press timer for games icon
  Timer? _iconHoldTimer;
  bool _iconHoldFired = false;
  // legacy BLE protocol reporting removed

  // Removed: pre-permission sheet. We now rely solely on OS dialogs.

  /// Native-styled "Open Settings" dialog for permanently denied permissions.
  Future<void> _showOpenSettingsDialog({
    required String title,
    required String message,
  }) async {
    if (Platform.isIOS) {
      await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Permission required',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          content: Text(message,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'Poppins')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  /// Request a single permission with native UX (pre-sheet + permanent-deny handling).
  Future<bool> _requestWithUX({
    required Permission permission,
    required String rationaleTitle,
    required String rationaleMessage,
  }) async {
    var status = await permission.status;

    // If not granted, request directly (no custom pre-permission sheet)
    if (!status.isGranted) {
      status = await permission.request();
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    // Permanently denied? Offer to open settings.
    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(
        title: 'Permission required',
        message: 'Please enable this permission in Settings to continue.',
      );
    } else {
      _showMessage('Permission not granted');
    }
    return false;
  }
// done

  /// Helper to get Android SDK version. Returns 0 on non-Android platforms.
  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  @override
  void initState() {
    super.initState();
    _bluetooth = widget.bluetooth;
    // Run permissions first, then init Bluetooth to avoid race/lag
    // _isConnected = widget.isConnected || _bluetooth.isConnected;
    _boot();
    LikeService.syncLikesToServer();

    // If we arrive already connected (e.g., auto-connect from WelcomePage),
    // ensure activation dialog is shown if not activated yet.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.isConnected && !_activationPromptShown) {
        try {
          final already = await ActivationService().isActivated();
          if (!already) {
            _activationPromptShown = true;
            await _promptActivationAfterConnect();
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _boot() async {
    try {
      final ok = await _requestPermissions();
      if (!ok) return;
    } catch (_) {
      return;
    }
    try {
      await _initBluetooth();
    } catch (_) {}
  }

  Future<String?> _publicIp() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _collectBleDetails() async {
    final Map<String, dynamic> details = {};
    try {
      final dev = _findCurrentConnectedBluetoothDevice();
      if (dev != null) {
        final services = await dev.discoverServices();
        final servicesJson = services
            .map((s) => {
                  'uuid': s.uuidString,
                  'characteristics': s.characteristics
                      .map((c) => {
                            'uuid': c.uuid.asString,
                            'properties': c.propSummary,
                          })
                      .toList(),
                })
            .toList();
        details['deviceId'] = dev.idString;
        details['deviceName'] = _bluetooth.connectedDeviceName ?? dev.nameString;
        details['services'] = servicesJson;
      }
      if (_selectedDevice != null) {
        details['macAddress'] = _selectedDevice!.macAddress;
      }
    } catch (_) {}
    return details;
  }

  Future<void> _promptActivationAfterConnect() async {
    // Show activation only if app not activated yet
    final already = await ActivationService().isActivated();
    if (already) return;
    _activationPromptShown = true;
    // final ip = await _publicIp();
    final ble = await _collectBleDetails();
    final extras = <String, dynamic>{
      // if (ip != null) 'ip': ip, // override ActivationService null
      if (ble.isNotEmpty) 'ble': ble,
    };

    final controller = TextEditingController();
    bool submitting = false;
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Activation',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your activation code to unlock the app.',
                      style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                          fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                      hintStyle: TextStyle(color: Colors.white24),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) async {
                      if (submitting) return;
                      setState(() => submitting = true);
                      final service = ActivationService();
                      final res = await service.activate(controller.text,
                          extra: extras);
                      if (!mounted) return;
                      setState(() => submitting = false);
                      if (res == ActivationResult.allow) {
                        Navigator.of(ctx).pop();
                        // Navigate only if connected too; otherwise stay on this page
                        if (_isConnected) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GamesScreen(
                                bluetooth: _bluetooth,
                                isConnected: _isConnected,
                              ),
                            ),
                          );
                        } else {
                          _showMessage('Connect first');
                        }
                      } else if (res == ActivationResult.deny) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Code already used.')));
                      } else if (res == ActivationResult.invalid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid code.')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Activation failed. Try again.')));
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setState(() => submitting = true);
                          final service = ActivationService();
                          final res = await service.activate(controller.text,
                              extra: extras);
                          if (!mounted) return;
                          setState(() => submitting = false);
                          if (res == ActivationResult.allow) {
                            Navigator.of(ctx).pop();
                            // Navigate only if connected; otherwise stay
                            if (_isConnected) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GamesScreen(
                                    bluetooth: _bluetooth,
                                    isConnected: _isConnected,
                                  ),
                                ),
                              );
                            } else {
                              _showMessage('Connect first');
                            }
                          } else if (res == ActivationResult.deny) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Code already used.')));
                          } else if (res == ActivationResult.invalid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid code.')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Activation failed. Try again.')));
                          }
                        },
                  child: Text(submitting ? 'SubmittingÃ¢â‚¬Â¦' : 'Submit'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// Activation popup for entering GamesScreen without connecting to a board.
  /// Uses a separate webhook so this flow is independent from the main app
  /// activation scenario, but still shares the same ActivationService logic.
  Future<void> _promptActivationWithoutBoard() async {
    // final ip = await _publicIp();
    final controller = TextEditingController();
    bool submitting = false;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Activation',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter your activation code to unlock the app without connecting to the board.',
                    style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) async {
                    if (submitting) return;
                    setState(() => submitting = true);
                    final service = ActivationService(
                      webhookUrl: Uri.parse(_kNoBoardWebhookUrl),
                      enforce16CharCodes: false,
                    );
                    final extras = <String, dynamic>{
                      'flow': 'no_board', // mark this pathway in Make scenario
                      'code': controller.text.trim(), // override formatted code
                      // if (ip != null) 'ip': ip,
                    };
                    final res =
                        await service.activate(controller.text, extra: extras);
                    if (!mounted) return;
                    setState(() => submitting = false);
                    _handleNoBoardActivationResult(ctx, res);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (controller.text.isEmpty) return;
                        setState(() => submitting = true);
                        final service = ActivationService(
                          webhookUrl: Uri.parse(_kNoBoardWebhookUrl),
                          enforce16CharCodes: false,
                        );
                        final extras = <String, dynamic>{
                          'flow': 'no_board',
                          'code': controller.text.trim(),
                          // if (ip != null) 'ip': ip,
                        };
                        final res = await service.activate(controller.text,
                            extra: extras);
                        if (!mounted) return;
                        setState(() => submitting = false);
                        _handleNoBoardActivationResult(ctx, res);
                      },
                child: Text(submitting ? 'SubmittingÃ¢â‚¬Â¦' : 'Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  void _handleNoBoardActivationResult(BuildContext ctx, ActivationResult res) {
    if (res == ActivationResult.allow) {
      Navigator.of(ctx).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GamesScreen(
            bluetooth: _bluetooth,
            isConnected: false,
          ),
        ),
      );
    } else if (res == ActivationResult.deny) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Code already used.')));
    } else if (res == ActivationResult.invalid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid code.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activation failed. Try again.')));
    }
  }

	  void _startIconHoldTimer() {
	    _iconHoldTimer?.cancel();
	    _iconHoldFired = false;
	    _iconHoldTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      _iconHoldFired = true;
      final activated = await ActivationService().isActivated();
      if (_isConnected) {
        if (!activated) {
          await _promptActivationAfterConnect();
        }
      } else {
        if (!activated) {
          await _promptActivationWithoutBoard();
        }
      }
    });
  }

  void _cancelIconHoldTimer() {
    _iconHoldTimer?.cancel();
    _iconHoldTimer = null;
  }

	  Future<void> _onGamesIconTapUp() async {
	    final alreadyFired = _iconHoldFired;
	    _cancelIconHoldTimer();
	    if (alreadyFired) return; // long-hold already handled popup
	
	    final service = ActivationService();
	    final alreadyActivated = await service.isActivated();
	
	    if (_isConnected) {
	      if (!alreadyActivated) {
	        return;
	      }
	      Navigator.push(
	        context,
	        MaterialPageRoute(
	          builder: (context) => GamesScreen(
	            bluetooth: _bluetooth,
	            isConnected: _isConnected,
	          ),
	        ),
	      );
	    } else {
	      if (!alreadyActivated) {
	        return;
	      }
	      Navigator.push(
	        context,
	        MaterialPageRoute(
	          builder: (context) => GamesScreen(
	            bluetooth: _bluetooth,
	            isConnected: false,
	          ),
	        ),
	      );
	    }
	  }

  Future<void> _cacheLastMacDevice(LedScreen device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastMacKey, device.macAddress.toUpperCase());
    } catch (_) {}
  }

  Future<String?> _getLastMac() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString(_kLastMacKey);
      if (mac != null && mac.isNotEmpty) {
        return mac.toUpperCase();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
	    return Scaffold(
	      // appBar: AppBar(
	      //   backgroundColor: Colors.black,
	      //   elevation: 0,
	      // ),
	      backgroundColor: Colors.black,
	      body: SafeArea(
	        child: Column(
	          children: [
	            Padding(
	              padding: const EdgeInsets.only(
	                  top: 20, left: 20, right: 20, bottom: 20),
	              child: Row(
	                mainAxisAlignment: MainAxisAlignment.spaceBetween,
	                children: [
	                  // Refresh / scan icon (fresh.svg)
		                  GestureDetector(
		                    onTap: () {
		                      if (_isScanning) {
		                        _stopScan();
		                      } else {
		                        _startScan();
		                      }
		                    },
		                    child: Container(
		                      width: 71,
		                      height: 71,
		                      decoration: BoxDecoration(
		                        shape: BoxShape.circle,
		                        color: Colors.white10,
		                      ),
		                      alignment: Alignment.center,
		                      child: _isScanning
		                          ? const SizedBox(
		                              width: 22,
		                              height: 22,
		                              child: CircularProgressIndicator(
		                                strokeWidth: 2,
		                                color: Colors.white,
		                              ),
		                            )
		                          : SvgPicture.asset(
		                              'assets/fresh.svg',
		                              width: 32,
		                              height: 32,
		                              colorFilter: const ColorFilter.mode(
		                                Colors.white,
		                                BlendMode.srcIn,
		                              ),
		                            ),
		                    ),
		                  ),
	                  // Back-to-games icon
	                  GestureDetector(
	                    behavior: HitTestBehavior.opaque,
	                    onTapDown: (_) => _startIconHoldTimer(),
	                    onTapUp: (_) => _onGamesIconTapUp(),
	                    onTapCancel: _cancelIconHoldTimer,
	                    child: Container(
	                      width: 71,
	                      height: 71,
	                      decoration: const BoxDecoration(
	                        shape: BoxShape.circle,
	                        color: Colors.white10,
	                      ),
	                      alignment: Alignment.center,
	                      child: const Icon(
	                        Icons.arrow_forward_ios,
	                        color: Colors.white,
	                      ),
	                    ),
	                  ),
	                ],
	              ),
	            ),
            const Text(
              "Search",
              style: TextStyle(
                  fontSize: 45,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 33),
            const Text(
              "Find and select your (Pixmat)",
              style: TextStyle(
                  color: Color.fromRGBO(139, 139, 139, 1),
                  fontSize: 14,
                  height: 1.6,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 80),
            const Text("Device List",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400)),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DottedLinePainter(
                  color: Color.fromARGB(255, 255, 255, 255),
                  strokeWidth: 1.0,
                  dashWidth: 4.0,
                  dashGap: 3.0,
                ),
              ),
            ),
            Expanded(
              child: _discoveredDevices.isEmpty
                  ? const Center(
                      child: Text("No devices found",
                          style: TextStyle(
                              color: Color(0xFF8B8B8B),
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400)),
                    )
                  : ListView.builder(
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        final isSelected =
                            _selectedDevice?.macAddress == device.macAddress;

                        return ListTile(
                          title: Text(device.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400)),
                          trailing: Text(
                            isSelected ? "Connect" : "Unknown",
                            style: const TextStyle(
                                color: Color(0xFF8B8B8B),
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400),
                          ),
                          selected: isSelected,
                          onTap: () => _connectToDevice(device),
                        );
                      },
                    ),
            ),
            if (_isConnected)
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connected: ${_selectedDevice?.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DottedLinePainter(
                  color: Color(0xFF8B8B8B),
                  strokeWidth: 1.0,
                  dashWidth: 4.0,
                  dashGap: 3.0,
                ),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Cannotfind()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: const Text(
                  "Can't Find?",
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<ui.Image> _createImageFromRGB(
      Uint8List rgbData, int width, int height) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbData,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        completer.complete(image);
      },
    );
    return completer.future;
  }

  @override
  void dispose() {
    _iconHoldTimer?.cancel();
    _iconHoldTimer = null;
    _discoverSub?.cancel();
    _scanSub?.cancel();
    _connStateSub?.cancel();
    // _bluetooth.dispose();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    // Initialize Bluetooth
    await _bluetooth.initialize();
  
    // Listen for device discovery events
    _discoverSub = _bluetooth.onDeviceDiscovered.listen((device) {
      setState(() {
        if (!_discoveredDevices.any((d) => d.macAddress == device.macAddress)) {
          _discoveredDevices.add(device);
        }
      });
    });

    _scanSub = _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str.toUpperCase();
        _deviceCache[id] = result.device;
        final normalized = id.replaceAll(RegExp(r'[:\-]'), '');
        _deviceCache[normalized] = result.device;
      }
    });
  
    // Listen for connection state changes
    _connStateSub = _connStateSub = _bluetooth.onConnectionStateChanged.listen((connected) async {
      setState(() {
        _isConnected = connected;
        if (!connected) {
          _connectedDevice = null;
          _selectedDevice = null;
          _navigatedToConnected = false;
          _activationPromptShown = false;
        }
      });
  
      if (!mounted || !connected) return;
      // Stop scanning early on connect
      if (_isScanning) {
        _stopScan();
      }
  
      // Gate navigation by activation status
      final activated = await ActivationService().isActivated();
      if (!activated) {
        if (!_activationPromptShown) {
          _activationPromptShown = true;
          await _promptActivationAfterConnect();
        }
        return;
      }
  
      // Only if already activated, show ConnectedScreen animation once
      if (!_navigatedToConnected) {
        _navigatedToConnected = true;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConnectedScreen(
              bluetooth: widget.bluetooth,
              isConnected: true,
            ),
          ),
        );
      }
    });

    // If already connected (e.g. from WelcomePage), skip auto-connect
    final alreadyConnected = widget.isConnected || _bluetooth.isConnected;
    if (!alreadyConnected) {
      // Try auto-connect to last device first
      final didAuto = await _tryAutoConnect();
      if (!didAuto) {
        _startScan();
      }
    } else {
      // Already connected: just populate device list and ensure logo is shown once.
      _startScan();
      try {
        if (_bluetooth.isConnected) {
          // Small stabilization delay on iOS before first large transfer
          if (Platform.isIOS) {
            await Future.delayed(const Duration(milliseconds: 150));
          }
          await _sendImageProgram();
        }
      } catch (_) {}
    }
  }

  Future<bool> _tryAutoConnect() async {
    final lastMac = await _getLastMac();
    if (lastMac == null) return false;

    try {
      await _bluetooth.startScan(timeout: const Duration(seconds: 6));
      final results = await FlutterBluePlus.scanResults.first;
      for (final r in results) {
        if (r.device.remoteId.str.toUpperCase() == lastMac) {
          await _bluetooth.stopScan();
          final advName = r.advertisementData.advName.trim();
          final resolvedName =
              advName.isNotEmpty ? advName : r.device.platformName;
          final ledScreen = LedScreen(
            name: resolvedName,
            macAddress: lastMac,
            width: ledWidth,
            height: ledHeight,
            colorType:
                _selectedDevice?.colorType ?? LedColorType.monochrome,
            rotation:
                _selectedDevice?.rotation ?? ScreenRotation.degree0,
            firmwareVersion:
                _selectedDevice?.firmwareVersion ?? '',
            device: r.device,
          );
          final success = await _bluetooth.connect(ledScreen);
          if (success) {
            setState(() {
              _selectedDevice = ledScreen;
              _connectedDevice = ledScreen.device;
              _isConnected = true;
            });
            DisplayManager.initialize(_bluetooth);
            await _sendImageProgram();
            return true;
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      await _bluetooth.stopScan();
    }
    return false;
  }

  Future<void> _startScan() async {
    setState(() {
      _discoveredDevices.clear();
      _isScanning = true;
    });

    try {
      await _bluetooth.startScan(timeout: const Duration(seconds: 10));
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    await _bluetooth.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(LedScreen device) async {
    // Stop scanning before attempting to connect (esp. important for iOS)
    await _bluetooth.stopScan();
    _isScanning = false;

    final success = await _bluetooth.connect(device);
    if (success) {
      setState(() {
        _selectedDevice = device;
        _connectedDevice = device.device;
      });
      _isConnected = true;
      DisplayManager.initialize(_bluetooth);
      await _cacheLastMacDevice(device);
      if (!mounted) return;
      // Small stabilization delay on iOS before first large transfer
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      // Send default logo program to the board after successful connect.
      await _sendImageProgram(); // Replace with your image path if needed
    } else {
      _showMessage('Failed to connect to device');
    }
  }

  Future<void> _disconnect() async {
    await _bluetooth.disconnect();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

//new
  Future<void> _sendTextProgram() async {
    if (!_isConnected) {
      _showMessage('Please connect to a device first');
      return;
    }

    try {
      var charBitmap = await TextData.getCharBitmap(
          "Hello", ledWidth, ledWidth, 2, Colors.red);
      final data = await charBitmap.toByteData();
      if (data == null) {
        _showMessage('Failed to send program');
        return;
      }
      img.Image? image = img.Image.fromBytes(
          width: ledWidth,
          height: ledWidth,
          bytes: data.buffer,
          numChannels: 4);
      final textData = image2bgr(image);
      final program = Program.text(
        partitionX: 0,
        partitionY: 0,
        partitionWidth: ledWidth,
        partitionHeight: ledWidth,
        textData: textData,
        specialEffect: SpecialEffect.leftShift,
        speed: 50,
        stayTime: 10,
        circularBorder: 0,
        brightness: 100,
      );

      final success =
          await _bluetooth.sendTemporaryProgram(program, circularBorder: 0);
      if (success) {
        _showMessage('Program sent successfully');
      } else {
        _showMessage('Failed to send program');
      }
    } catch (e) {
      _showMessage('Error sending program: $e');
    }
  }

  Future<Uint8List> loadBmpAssetAsBgrBmp(String path) async {
    // Load image file from assets
    ByteData data = await rootBundle.load(path);

    // Decode image
    final img.Image? originalImage = img.decodeImage(data.buffer.asUint8List());
    if (originalImage == null) {
      throw Exception('Unable to decode image');
    }

    return loadImageData(originalImage);
  }

  Future<Uint8List> loadImageData(img.Image originalImage) async {
    // Resize to match LED screen
    final img.Image resizedImage =
        img.copyResize(originalImage, width: ledWidth, height: ledWidth);
    return image2bgr(resizedImage);
  }

  Uint8List image2bgr(img.Image resizedImage) {
    List<int> ledData = [];
    // Convert color channel order from RGB to BGR
    for (int y = 0; y < ledWidth; y++) {
      for (int x = 0; x < ledWidth; x++) {
        // Get pixel value (RGBA format)
        final pixel = resizedImage.getPixel(x, y);

        // Extract RGB channel values
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        ledData.add(r); // R component
        ledData.add(g); // G component
        ledData.add(b); // B component
      }
    }
    return Uint8List.fromList(ledData);
  }

  Future<bool> _sendImageProgram() async {
    if (!_bluetooth.isConnected) {
      _showMessage('Please connect to a device first');
      return false;
    }
    try {
      final bmp = await loadBmpAssetAsBgrBmp('assets/logopixply.png');
      await _bluetooth.deleteAllPrograms();
      final program = Program.bmp(
        partitionX: 0,
        partitionY: 0,
        bmpData: bmp,
        partitionWidth: ledWidth,
        partitionHeight: ledHeight,
        specialEffect: SpecialEffect.fixed,
        speed: 50,
        stayTime: 300000,
        circularBorder: 0,
        brightness: 100,
      );
      await _bluetooth.addProgramToPlaylist(
        program,
        programCount: 1,
        programNumber: 0,
        playbackCount: 1,
        circularBorder: 0,
      );
      final ok = await _bluetooth.updatePlaylistComplete();
      _showMessage(ok ? 'Image playlist sent' : 'Failed to send image playlist');
      return ok;
    } catch (e) {
      _showMessage('Error sending image: $e');
      return false;
    }
  }

  Future<bool> _requestPermissions() async {



    if (Platform.isAndroid) {
      final sdk = await _androidSdkInt();

      if (sdk >= 31) {
        // Android 12+: Nearby Devices permissions
        final okScan = await _requestWithUX(
          permission: Permission.bluetoothScan,
          rationaleTitle: 'Allow Bluetooth scanning',
          rationaleMessage:
              'Pixply needs Bluetooth scan permission to discover your Pixmat board nearby.',
        );
        if (!okScan) return false;

        final okConnect = await _requestWithUX(
          permission: Permission.bluetoothConnect,
          rationaleTitle: 'Allow Bluetooth connection',
          rationaleMessage:
              'Pixply needs Bluetooth connect permission to pair and communicate with your board.',
        );
        if (!okConnect) return false;

        // Bluetooth adapter state with timeout fallback to reduce lag
        BluetoothAdapterState btState;
        try {
          btState = await FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 2));
        } on TimeoutException {
          btState = BluetoothAdapterState.unknown;
        }
        if (btState != BluetoothAdapterState.on) {
          _showMessage('Turning on Bluetooth...');
          await FlutterBluePlus.turnOn();
        }
      } else {
        // Android 11 and below: Location permission needed for BLE scans
        final okLocation = await _requestWithUX(
          permission: Permission.locationWhenInUse,
          rationaleTitle: 'Allow Location (while using the app)',
          rationaleMessage:
              'Android requires Location permission to scan for Bluetooth devices nearby.',
        );
        if (!okLocation) return false;

        // Ensure location services are ON (system setting)
        final serviceEnabled =
            await Permission.locationWhenInUse.serviceStatus.isEnabled;
        if (!serviceEnabled) {
          await _showOpenSettingsDialog(
            title: 'Turn on Location',
            message:
                'Location services are turned off. Please enable them to discover your board.',
          );
          return false;
        }

        // Bluetooth adapter state with timeout fallback to reduce lag
        BluetoothAdapterState btState;
        try {
          btState = await FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 2));
        } on TimeoutException {
          btState = BluetoothAdapterState.unknown;
        }
        if (btState != BluetoothAdapterState.on) {
          _showMessage('Turning on Bluetooth...');
          await FlutterBluePlus.turnOn();
        }
      }
    } else if (Platform.isIOS) {
      // iOS: avoid blocking dialogs here. Let user enable BT from Control Center.
      // We only read current state and show a non-blocking hint if needed.
      BluetoothAdapterState btState;
      try {
        btState = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        btState = BluetoothAdapterState.unknown;
      }
      if (btState != BluetoothAdapterState.on) {
        _showMessage('Bluetooth is off. Enable it to scan for your board.');
      }
    } else {
      // Desktop/Web: no runtime permissions needed
      return true;
    }
    return true;
  }
}

extension on Guid {
  String get asString {
    try {
      // flutter_blue_plus Guid typically has .str; fallback to toString
      // ignore: invalid_use_of_protected_member
      // ignore: unnecessary_this
      // Using dynamic to avoid hard dependency on .str at analysis time
      final dyn = this as dynamic;
      return (dyn.str as String?) ?? toString();
    } catch (_) {
      return toString();
    }
  }
}

extension on BluetoothDevice {
  String get idString {
    try {
      final dyn = remoteId as dynamic;
      return (dyn.str as String?) ?? remoteId.toString();
    } catch (_) {
      return remoteId.toString();
    }
  }

  String get nameString {
    try {
      return platformName;
    } catch (_) {
      return toString();
    }
  }
}

extension on BluetoothCharacteristic {
  Map<String, dynamic> get propSummary {
    final p = properties;
    return {
      'read': p.read,
      'write': p.write,
      'writeWithoutResponse': p.writeWithoutResponse,
      'notify': p.notify,
      'indicate': p.indicate,
    };
  }
}

extension on BluetoothService {
  String get uuidString {
    try {
      return uuid.asString;
    } catch (_) {
      return uuid.toString();
    }
  }
}

extension _ProtocolSender on _ConnectionPageState {
  BluetoothDevice? _findCurrentConnectedBluetoothDevice() {
    if (_connectedDevice != null) return _connectedDevice;
    try {
      // Try match by selected device MAC
      final mac = _selectedDevice?.macAddress.toUpperCase();
      if (mac != null && mac.isNotEmpty) {
        for (final d in FlutterBluePlus.connectedDevices) {
          if (d.remoteId.str.toUpperCase() == mac) return d;
        }
      }
    } catch (_) {}
    try {
      // Fallback: first connected device
      if (FlutterBluePlus.connectedDevices.isNotEmpty) {
        return FlutterBluePlus.connectedDevices.first;
      }
    } catch (_) {}
    return null;
  }
}
