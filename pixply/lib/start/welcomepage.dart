import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:pixply/onboarding/onboarding_instructions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pixply/games.dart';
import 'package:pixply/connection.dart';
import 'package:pixply/core/activation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pixply/connected.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// import 'dart:typed_data';
// import 'package:pixply/text_data_lib.dart';


class WelcomePage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;

  const WelcomePage({super.key, required this.bluetooth, required this.isConnected});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  double _fadeOverlay = 0.0;
  bool _showLoading = false;
  static const String _kTermsAcceptedKey = 'pixply_terms_accepted_v1';
  static const String _kWelcomeSeenKey = 'pixply_welcome_seen_v1'; // NEW
  String _welcomeTitle = 'Welcome'; // NEW
  final _secure = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
     _initWelcomeTitle(); // NEW
    // After initial animation, decide where to go
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (!mounted) return;
      setState(() {
        _fadeOverlay = 1.0;
        _showLoading = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted) return;
        await _routeNext();
      });
    });
  }

  static const String _kLastMacKey = 'last_pixmat_mac';

  Future<bool> _onboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenVer = prefs.getInt(OnboardingScreen.kPrefsKey) ?? 0;
      return seenVer == OnboardingScreen.kVersion;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getLastMac() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString(_kLastMacKey);
      if (mac != null && mac.isNotEmpty) return mac.toUpperCase();
    } catch (_) {}
    return null;
  }

  Future<bool> _termsAccepted() async {
    try {
      final v = await _secure.read(key: _kTermsAcceptedKey);
      if (v == 'true' || v == '1') return true;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kTermsAcceptedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureBluetoothOn({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      // Get a quick snapshot; on iOS right after launch this can be `unknown` for a short time.
      BluetoothAdapterState state;
      try {
        state = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        state = BluetoothAdapterState.unknown;
      }
      if (state == BluetoothAdapterState.on) return true;

      final end = DateTime.now().add(timeout);
      bool prompted = false;

      // Listen for state changes while we wait, to avoid polling and to catch transitions from unknown->on.
      final sub = FlutterBluePlus.adapterState.listen((s) {
        state = s;
      });

      while (mounted && DateTime.now().isBefore(end)) {
        if (state == BluetoothAdapterState.on) {
          await sub.cancel();
          return true;
        }

        // Show prompt only if state is explicitly OFF, and avoid blocking prompts on iOS.
        if (!prompted && state == BluetoothAdapterState.off && !Platform.isIOS) {
          prompted = true;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Enable Bluetooth', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              content: const Text(
                'Please enable Bluetooth to auto-connect to your Pixmat.',
                style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      await sub.cancel();
    } catch (_) {}
    return false;
  }

  Future<Uint8List> _loadBmpAssetAsBgrBmp(String path) async {
    final data = await rootBundle.load(path);
    final img.Image? original =
        img.decodeImage(data.buffer.asUint8List());
    if (original == null) {
      throw Exception('Unable to decode image');
    }

    const int ledWidth = 56;
    const int ledHeight = 56;
    final img.Image resized =
        img.copyResize(original, width: ledWidth, height: ledHeight);

    final List<int> buffer = [];
    for (int y = 0; y < ledHeight; y++) {
      for (int x = 0; x < ledWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        buffer.add(r);
        buffer.add(g);
        buffer.add(b);
      }
    }
    return Uint8List.fromList(buffer);
  }

  Future<void> _sendLogoAfterConnect() async {
    if (!widget.bluetooth.isConnected) {
      return;
    }

    // iOS: از مسیر قدیمی و پایدار DisplayManager برای لوگو استفاده کن
    if (Platform.isIOS) {
      try {
        DisplayManager.initialize(widget.bluetooth);
        DisplayManager.recordLastDisplay(
          path: 'assets/logopixply.png',
          type: DisplayType.image,
        );
        await DisplayManager.refreshDisplay();
        return;
      } catch (_) {
        // خطا در ارسال لوگو نباید فلو ناوبری را خراب کند
        return;
      }
    }

    // اگر همین لوگو همین حالا روی برد است، دوباره نفرست
    try {
      // آماده‌سازی برد مثل منطق ConnectionPage / Achi
      await widget.bluetooth.switchLedScreen(true);
      await widget.bluetooth.setBrightness(Brightness.high);
      await widget.bluetooth.deleteAllPrograms();
      await widget.bluetooth.updatePlaylistComplete();

      final bmp =
          await _loadBmpAssetAsBgrBmp('assets/logopixply.png');

      const int ledWidth = 56;
      const int ledHeight = 56;
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

      await widget.bluetooth.addProgramToPlaylist(
        program,
        programCount: 1,
        programNumber: 0,
        playbackCount: 1,
        circularBorder: 0,
      );

      var ok = await widget.bluetooth.updatePlaylistComplete();
      if (!ok) {
        await Future.delayed(const Duration(seconds: 1));
        ok = await widget.bluetooth.updatePlaylistComplete();
      }

      // برای هماهنگی با سیستم تنظیمات
      DisplayManager.initialize(widget.bluetooth);
      DisplayManager.recordLastDisplay(
        path: 'assets/logopixply.png',
        type: DisplayType.image,
      );
    } catch (_) {
      // خطا در ارسال لوگو نباید فلو ناوبری را خراب کند
    }
  }

  Future<bool> _autoConnectToLast() async {
    final lastMac = await _getLastMac();
    if (lastMac == null) return false;
    try {
      for (final d in FlutterBluePlus.connectedDevices) {
        if (d.remoteId.str.toUpperCase() == lastMac) {
          final ok = await widget.bluetooth.connect(d);
          if (ok) {
            await _sendLogoAfterConnect();
          }
          return ok;
        }
      }
      await widget.bluetooth.startScan(timeout: const Duration(seconds: 6));
      final results = await FlutterBluePlus.scanResults.first;
      BluetoothDevice? found;
      for (final r in results) {
        if (r.device.remoteId.str.toUpperCase() == lastMac) { found = r.device; break; }
      }
      await widget.bluetooth.stopScan();
      if (found == null) return false;
      final ok = await widget.bluetooth.connect(found);
      if (ok) {
        await _sendLogoAfterConnect();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _routeNext() async {
    final seen = await _onboardingSeen();

    if (!seen) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    // After onboarding has been completed at least once, enforce
    // the brake/terms condition before proceeding further.
    final termsOk = await _termsAccepted();
    if (!termsOk) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConnectedPage(
            bluetooth: widget.bluetooth,
            isConnected: false,
          ),
        ),
      );
      return;
    }

    final btOn = await _ensureBluetoothOn();
    if (btOn) {
      final ok = await _autoConnectToLast();
      if (ok) {
        try {
          final activated = await ActivationService().isActivated();
          if (!mounted) return;
          if (activated) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GamesScreen(
                  bluetooth: widget.bluetooth,
                  isConnected: true,
                ),
              ),
            );
          } else {
            // Route to ConnectionPage (already connected) to show activation prompt
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ConnectionPage(
                  bluetooth: widget.bluetooth,
                  isConnected: true,
                ),
              ),
            );
          }
        } catch (_) {
          // On error fallback to ConnectionPage
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ConnectionPage(
                bluetooth: widget.bluetooth,
                isConnected: true,
              ),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectionPage(
          bluetooth: widget.bluetooth,
          isConnected: false,
        ),
      ),
    );
  }
    Future<void> _initWelcomeTitle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_kWelcomeSeenKey) ?? false;

      if (seen) {
        if (!mounted) return;
        setState(() {
          _welcomeTitle = 'Welcome back';
        });
      } else {
        // اولین بار
        await prefs.setBool(_kWelcomeSeenKey, true);
        // همین 'Welcome' پیش‌فرض می‌ماند
      }
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:  [
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Text(
                         _welcomeTitle, 
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          Text(
                            'Unroll, Play, Connect',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: _fadeOverlay,
              child: Container(
                color: Colors.black,
                child: _showLoading
                    ? const Center(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
