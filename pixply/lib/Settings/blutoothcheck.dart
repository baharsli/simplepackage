import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:led_ble_lib/led_ble_lib.dart';

class BluetoothCheckPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;
  const BluetoothCheckPage({
    super.key,
    required this.bluetooth,
    required this.isConnected,
  });

  @override
  State<BluetoothCheckPage> createState() => _BluetoothCheckPageState();
}

class _BluetoothCheckPageState extends State<BluetoothCheckPage> {
  late final LedBluetooth _bluetooth;
  final List<LedScreen> _devices = [];
  LedScreen? _selected; // last chosen/connected screen
  BluetoothDevice? _btDevice; // underlying FlutterBlue device
  bool _isScanning = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _bluetooth = widget.bluetooth;
    _isConnected = widget.isConnected || _bluetooth.isConnected;

    // device discovery (LedScreen)
    _bluetooth.onDeviceDiscovered.listen((screen) {
      if (!mounted) return;
      setState(() {
        if (_devices.every((d) => d.macAddress != screen.macAddress)) {
          _devices.add(screen);
        }
      });
    });

    // connection state
    _bluetooth.onConnectionStateChanged.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (!connected) {
          _selected = null;
          _btDevice = null;
        }
      });
      if (!connected) {
        _startScan();
      }
    });

    if (_isConnected) {
      // optional best-effort: try to show current connected device if known later via scan
      _startScan();
    } else {
      _startScan();
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });
    try {
      await _bluetooth.startScan(timeout: const Duration(seconds: 10));
    } finally {
      if (!mounted) return ;
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(LedScreen screen) async {
    final ok = await _bluetooth.connect(screen);
    if (!ok) {
      _toast('Failed to connect');
      return;
    }

    setState(() {
      _selected = screen;
      _btDevice = screen.device;
    });
    _toast('Connected');
  }

  Future<void> _disconnect() async {
    await _bluetooth.disconnect();
    _toast('Disconnected');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 71,
              height: 71,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/back.svg',
                  width: 35,
                  height: 35,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          Column(
            children: [
              SvgPicture.asset(
                'assets/bluetooth.svg',
                width: 38,
                height: 38,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _startScan,
            child: Container(
              width: 71,
              height: 71,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isScanning
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : SvgPicture.asset(
                        'assets/fresh.svg',
                        width: 35,
                        height: 35,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard() {
    final title = _selected?.name.isNotEmpty == true
        ? _selected!.name
        : (_btDevice?.platformName.isNotEmpty == true ? _btDevice!.platformName : 'Connected Device');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF8BE671),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _disconnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Disconnect',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(LedScreen screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF5A5A5A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                screen.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _connect(screen),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isConnected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _connectedCard(),
          const SizedBox(height: 12),
        ],
      );
    }

    if (_devices.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'No device found',
            style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (_, i) => _deviceTile(_devices[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 10),
            _body(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
