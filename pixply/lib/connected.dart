import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:pixply/connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:pixply/games.dart';

class ConnectedPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;

  const ConnectedPage({super.key, required this.bluetooth, required this.isConnected});

  @override
  State<ConnectedPage> createState() => _ConnectedPageState();
}

class _ConnectedPageState extends State<ConnectedPage> {
  // Consent constants (kept identical to termsconditions.dart)
  static const String kTermsAcceptedKey = 'pixply_terms_accepted_v1';
  static const String kUserIdKey = 'pixply_user_id';
  static const String _kPendingConsentKey = 'pixply_pending_consent_v1';
  static const String kWebhookUrl = 'https://hook.eu2.make.com/j798ph0qy57ab49kucld3b7r9hm8f2by';
  static const String kWebhookApiKey = 'Lm6t@9kQpj#';
  static const String kWebhookApiHeader = 'X-Api-Key';

  static const String kPrivacyUrl = 'https://www.pixply.io/pixply-app-privacy-policy';
  static const String kTermsUrl = 'https://www.pixply.io/pixply-app-terms-and-conditions';

  final _secure = const FlutterSecureStorage();

  bool _agree = false;
  bool _consentRecorded = false;
  bool _submitting = false;
  Future<void>? _consentFuture;

  @override
  void initState() {
    super.initState();
    _loadConsent();
    _flushPendingConsent();
  }

  Future<void> _loadConsent() async {
    try {
      final v = await _secure.read(key: kTermsAcceptedKey);
      final accepted = (v == 'true' || v == '1');
      if (!accepted) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(kTermsAcceptedKey) == true) {
          setState(() => _consentRecorded = true);
          return;
        }
      }
      setState(() => _consentRecorded = accepted);
    } catch (_) {}
  }

  Future<void> _flushPendingConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingConsentKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      await _sendConsentToServer(decoded);
      await prefs.remove(_kPendingConsentKey);
    } catch (_) {
      // keep pending payload for next attempt
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final res = await InternetAddress.lookup('example.com');
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getPublicIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
    } catch (_) {}
    return null;
  }

  String _randomId({int len = 24}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> _getOrCreateUserId() async {
    try {
      String? uid = await _secure.read(key: kUserIdKey);
      if (uid != null && uid.isNotEmpty) return uid;
      uid = _randomId();
      await _secure.write(key: kUserIdKey, value: uid);
      return uid;
    } catch (_) {
      return _randomId();
    }
  }

  Future<String> _getDeviceModel() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return '${android.manufacturer} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        final name = ios.name;
        final model = ios.model;
        return name != null && name.isNotEmpty ? name : (model ?? 'iOS');
      } else {
        return Platform.operatingSystem;
      }
    } catch (_) {
      return Platform.operatingSystem;
    }
  }

  Future<void> _sendConsentToServer(Map<String, dynamic> payload) async {
    try {
      final resp = await http
          .post(
            Uri.parse(kWebhookUrl),
            headers: {
              'Content-Type': 'application/json',
              kWebhookApiHeader: kWebhookApiKey,
              'X-IMT-Execution-Key': kWebhookApiKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // Do not expose response body or URL details
        throw Exception('submit_failed');
      }
    } on SocketException catch (e) {
      debugPrint('Consent SocketException: $e');
      throw Exception('no_internet');
    } on http.ClientException catch (e) {
      debugPrint('Consent ClientException: ${e.message} uri=${e.uri}');
      throw Exception('network_error');
    } on FormatException catch (e) {
      debugPrint('Consent FormatException: $e');
      throw Exception('network_error');
    } on TimeoutException catch (_) {
      throw Exception('network_timeout');
    }
  }

  Future<void> _confirmConsent() async {
    // If a consent submission is already in progress (e.g. started from
    // the checkbox), reuse that Future so the first tap on the button
    // will wait for it instead of requiring a second tap.
    if (_consentFuture != null) {
      return _consentFuture!;
    }

    _consentFuture = _confirmConsentImpl();
    try {
      await _consentFuture!;
    } finally {
      _consentFuture = null;
    }
  }

  Future<void> _confirmConsentImpl() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    if (!_agree) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to continue.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final online = await _hasInternet();
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet may be offline; attempting to submit anyway.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final userId = await _getOrCreateUserId();
    final nowIso = DateTime.now().toIso8601String();
    final localeTag = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    final platform = Theme.of(context).platform.name;
    // final ip = await _getPublicIp();
    final model = await _getDeviceModel();

    final payload = {
      'event': 'terms_consent',
      'user_id': userId,
      'timestamp': nowIso,
      'locale': localeTag,
      'platform': platform,
      'device_model': model,
      // 'ip_address': ip,
      'app_area': 'connected.dart',
      'accepted_required': true,
      'accepted_all': true,
      'accepted_items': [
        {'key': 'terms', 'title': 'Terms & Conditions', 'link': kTermsUrl},
        {'key': 'privacy', 'title': 'Privacy Policy', 'link': kPrivacyUrl},
      ],
    };

    bool sent = false;
    final prefs = await SharedPreferences.getInstance();
    try {
      await _sendConsentToServer(payload);
      sent = true;
      await prefs.remove(_kPendingConsentKey);
    } catch (_) {
      // Cache locally and retry later when connectivity is available.
      await prefs.setString(_kPendingConsentKey, jsonEncode(payload));
    }

    await _secure.write(key: kTermsAcceptedKey, value: 'true');
    await prefs.setBool(kTermsAcceptedKey, true);
    setState(() => _consentRecorded = true);

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved. Will submit once internet is available.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => _submitting = false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tap Search Pixmat and the app instantly scans for your board. Make sure it’s powered on, nearby, and permissions are enabled – then connect seamlessly. Unroll your Pixmat, tap search, and dive straight into the game library.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B8B8B),
                    height: 1.6,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),

                // Terms / Privacy agreement block
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agree,
                        onChanged: (v) async {
                          if (_submitting) return;
                          final nv = v ?? false;
                          setState(() => _agree = nv);
                          if (nv && !_consentRecorded) {
                            await _confirmConsent();
                          }
                        },
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14, height: 1.5),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline , fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
                                recognizer: TapGestureRecognizer()..onTap = () => _openUrl(kTermsUrl),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline , fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
                                recognizer: TapGestureRecognizer()..onTap = () => _openUrl(kPrivacyUrl),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Spacer(),
                // NEW: Continue without connect to board button
// Container(
//   margin: const EdgeInsets.symmetric(horizontal: 20),
//   height: 82,
//   width: double.infinity,
//   child: ElevatedButton(
//     onPressed: () async {
//       // همچنان همان منطق رضایت (Terms & Privacy) را رعایت می‌کنیم
//       if (!_consentRecorded) {
//         if (!_agree) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Please check the box to agree to Terms & Privacy.'),
//               duration: Duration(seconds: 2),
//             ),
//           );
//           return;
//         }
//         await _confirmConsent();
//         if (!_consentRecorded) return;
//       }

//       // بدون اتصال به بورد، مستقیم به GamesPage برو
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => GamesScreen(bluetooth: widget.bluetooth, isConnected: widget.isConnected), 
//           // اگر GamesPage پارامتر می‌گیرد، اینجا مطابق امضا تغییر بده:
//           // GamesScreen(bluetooth: widget.bluetooth, isConnected: widget.isConnected),
//         ),
//       );
//     },
//     style: ElevatedButton.styleFrom(
//       backgroundColor: const Color(0xFF313131),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(41),
//       ),
//     ),
//     child: const Text(
//       'Continue without connect to board',
//       textAlign: TextAlign.center,
//       style: TextStyle(
//         fontWeight: FontWeight.w600,
//         color: Colors.white,
//         fontSize: 16, // کمی کوچک‌تر تا متن طولانی جا شود
//         fontFamily: 'Poppins',
//       ),
//     ),
//   ),
// ),

// const SizedBox(height: 20),

                // Search Pixmat button (enabled only after consent)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 82,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Enforce consent before proceeding
                      if (!_consentRecorded) {
                        if (!_agree) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please check the box to agree to Terms & Privacy.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        await _confirmConsent();
                        if (!_consentRecorded) return; // sending failed or cancelled
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Container(color: Colors.black);
                        },
                      );
                      await Future.delayed(const Duration(milliseconds: 500));
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConnectionPage(
                            bluetooth: widget.bluetooth,
                            isConnected: widget.isConnected,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF313131),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(41),
                      ),
                    ),
                    child: const Text(
                      'Search Pixmat',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
