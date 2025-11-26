// lib/force_update_gate.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ForceUpdateGate extends StatefulWidget {
  final Widget child;
  final String remoteJsonUrl;   // e.g. https://baharsli.github.io/Pixo-config/app-config.json
  final String androidStoreUrl; // Play Store link
  final String iosAppStoreUrl;  // App Store link

  const ForceUpdateGate({
    super.key,
    required this.child,
    required this.remoteJsonUrl,
    required this.androidStoreUrl,
    required this.iosAppStoreUrl,
  });

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  bool _checked = false;
  bool _mustBlock = false;
  bool _suggest = false;
  String _message = 'An update is required to continue.';
  String _suggestMsg = 'A new update is available.';
  bool _checking = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  List<int> _v(String v) => v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  int _cmp(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _check();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
      if (!isOffline && !_checked) {
        _check();
      }
    });
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      // Skip remote call when offline so startup never blocks.
      final conn = await Connectivity().checkConnectivity();
      final offline = conn.isEmpty || (conn.length == 1 && conn.first == ConnectivityResult.none);
      if (offline) {
        if (!mounted) return;
        setState(() {
          _checked = false;
          _suggest = false;
        });
        _checking = false;
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final current = _v(info.version);

      final url = '${widget.remoteJsonUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      final j = json.decode(res.body) as Map<String, dynamic>;

      final maintenance = j['maintenance'] == true;
      final minSupported = (j['min_supported'] ?? '0.0.0').toString();
      final latest = (j['latest'] ?? '0.0.0').toString();

      _message = (j['block_message'] ??
              'Your current version is no longer supported. Please update the app.')
          .toString();
      _suggestMsg = (j['suggest_message'] ?? 'A new update is available.').toString();

      final mustUpdate = maintenance || _cmp(current, _v(minSupported)) < 0 || _cmp(current, _v(latest)) < 0;

      if (!mounted) return;
      setState(() {
        _suggest = mustUpdate;
        _checked = true;
      });
      _checking = false;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checked = false;
        _suggest = false;
      });
      _checking = false; // اگر نتوانست کانفیگ بخواند، قفل نکن
    }
  }

  void _openStore() {
    final url = Platform.isAndroid ? widget.androidStoreUrl : widget.iosAppStoreUrl;
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تا وقتی نتیجه چک نسخه آماده نشده
    if (!_checked) {
      return widget.child;
    }

    // *** حالت قفل کامل: هیچ ویجت دیگری (از جمله اسپلش) ساخته نمی‌شود ***
    if (_mustBlock) {
      return WillPopScope(
        onWillPop: () async => false, // بک ممنوع
        child: Scaffold(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // const Icon(Icons.system_update, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20 , fontFamily: 'Poppins', color: Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(50, 50, 50, 1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(41),
                          ),
                        ),
                        onPressed: _openStore,
                        child: const Text('Update from Store' , style: TextStyle(fontFamily: 'Poppins', fontSize: 16 , fontWeight: FontWeight.w400, color:  Color.fromARGB(255, 255, 255, 255), ),),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // حالت نرمال: اپ را نشان بده و اگر فقط پیشنهاد آپدیت است، یک بنر کوچک بده
    return Stack(
      children: [
        widget.child,
        if (_suggest)
          Positioned(
            left: 12, right: 12, bottom: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: const Color.fromARGB(49, 49, 49, 1),
              child: ListTile(
                title: Text(_suggestMsg, style: const TextStyle(color: Colors.white , fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
                trailing: TextButton(
                  onPressed: _openStore,
                  child: const Text('Update', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
