import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PixStudioActivationPatch {
  // ====== تنظیمات بای‌پس (بدون سرور) ======
  static const String _kBypassCode = 'PIX-RCZ1ZNBD';
  static const String _kWebhookUrl =
      'https://hook.eu2.make.com/9cbt7liftpd6tl8yfr060lfdcw8pum1d';

  // ====== کلیدهای SecureStorage (تغییر نکرده) ======
  static const String _kUnlockedKey = 'pixstudio_unlocked_v1';
  static const String _kBoundDeviceKey = 'pixstudio_bound_device_v1';

  // یک نمونه‌ی Shared از SecureStorage
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<String> _getOrCreateDeviceId() async {
    final existing = await _secure.read(key: _kBoundDeviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random();
    final id =
        'dev_${DateTime.now().millisecondsSinceEpoch}_${rnd.nextInt(0x7fffffff)}';
    await _secure.write(key: _kBoundDeviceKey, value: id);
    return id;
  }

  /// بررسی سریع: آیا قبلاً فعال شده؟
  static Future<bool> isUnlocked() async {
    final val = await _secure.read(key: _kUnlockedKey);
    return val == 'true';
  }

  /// فعال‌سازی لوکال (بدون هیچ درخواست شبکه‌ای)
  ///
  /// ورودی: [code] همان رمزی که کاربر وارد می‌کند.
  /// [deviceFingerprint] اختیاری است؛ اگر مقدار داشته باشد ذخیره می‌شود.
  ///
  /// خروجی دقیقاً مانند نسخه‌ی آنلاین است: "allow" یا "invalid"
  static Future<String> activate({
    required String code,
    String? deviceFingerprint,
  }) async {
    // اگر قبلاً فعال شده باشد، مستقیم allow بده
    if (await isUnlocked()) {
      if (kDebugMode) {
        // print('[PixStudio] Already unlocked (persisted).');
      }
      return 'allow';
    }

    // مقایسه‌ی کد (حساس به حروف، در صورت نیاز می‌توان toUpperCase کرد)
    final entered = code.trim();
    if (entered == _kBypassCode) {
      // ذخیره‌ی وضعیت فعال‌سازی
      await _secure.write(key: _kUnlockedKey, value: 'true');

      // ذخیره‌ی اثرانگشت دستگاه (اختیاری برای استفاده‌های بعدی)
      if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
        await _secure.write(key: _kBoundDeviceKey, value: deviceFingerprint);
      }

      if (kDebugMode) {
        // print('[PixStudio] Activated locally via bypass code.');
      }
      return 'allow';
    }

    // هر کد دیگری نامعتبر است
    return 'invalid';
  }

  /// بازنشانی وضعیت (اختیاری برای دیباگ)
  static Future<void> resetActivation() async {
    await _secure.delete(key: _kUnlockedKey);
    await _secure.delete(key: _kBoundDeviceKey);
  }

  /// دریافت اثرانگشت ذخیره‌شده (اگر وجود داشته باشد)
  static Future<String?> boundDevice() => _secure.read(key: _kBoundDeviceKey);
}
 
extension PixStudioActivationPatchWebhook on PixStudioActivationPatch {
  /// Activate by sending the code to Make.com webhook.
  static Future<String> activateViaWebhook({
    required String code,
    String? deviceFingerprint,
  }) async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
    if (offline) return 'allow'; // do not block when offline

    if (await PixStudioActivationPatch.isUnlocked()) return 'allow';

    final entered = code.trim();
    if (entered == PixStudioActivationPatch._kBypassCode) {
      await PixStudioActivationPatch._secure
          .write(key: PixStudioActivationPatch._kUnlockedKey, value: 'true');
      if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
        await PixStudioActivationPatch._secure.write(
            key: PixStudioActivationPatch._kBoundDeviceKey,
            value: deviceFingerprint);
      }
      return 'allow';
    }

    try {
      final deviceId = deviceFingerprint ??
          await PixStudioActivationPatch._getOrCreateDeviceId();

      // Normalize code only for sending
      final codeUpper = entered.toUpperCase();

      // Attempt to fetch public IP (2s timeout). Fail-safe to null.
      // String? ip;
      // try {
      //   final ipResp = await http
      //       .get(Uri.parse('https://api.ipify.org?format=json'))
      //       .timeout(const Duration(seconds: 2));
      //   if (ipResp.statusCode == 200) {
      //     final ipJson = jsonDecode(ipResp.body);
      //     if (ipJson is Map && ipJson['ip'] is String) {
      //       ip = ipJson['ip'] as String;
      //     }
      //   }
      // } catch (_) {
      //   ip = null;
      // }

      // Try to read app version; fail-safe to null.
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        appVersion = null;
      }

String? deviceModel;
try {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final a = await deviceInfo.androidInfo;
    // ترکیب کامل‌تر با fallback
    final manu = (a.manufacturer ?? '').trim();
    final model = (a.model ?? '').trim();
    final device = (a.device ?? '').trim();
    final brand = (a.brand ?? '').trim();
    deviceModel = [
      // اولویت: manufacturer + model
      [manu, model].where((e) => e.isNotEmpty).join(' '),
      // fallback: brand/device داخل پرانتز
      if (brand.isNotEmpty || device.isNotEmpty)
        '(${[brand, device].where((e) => e.isNotEmpty).join('/')})'
    ].where((e) => e.isNotEmpty).join(' ');
    if (deviceModel.isEmpty) deviceModel = null;
  } else if (Platform.isIOS) {
    final i = await deviceInfo.iosInfo;
    // مدل انسانی + شناسهٔ ماشین (برای دقت)
    final model = (i.model ?? '').trim();                // e.g. iPhone
    final machine = (i.utsname.machine ?? '').trim();    // e.g. iPhone13,4
    deviceModel = [model, if (machine.isNotEmpty) '($machine)']
        .where((e) => e.isNotEmpty)
        .join(' ');
    if (deviceModel.isEmpty) deviceModel = null;
  }
} catch (_) {
  deviceModel = null;
}

// زمان ورود (local) جدا از sentAt (UTC)
final loginTime = DateTime.now().toIso8601String();



      final sentAt = DateTime.now().toUtc().toIso8601String();

      final Map<String, dynamic> body = {
        'code': codeUpper,
        'deviceId': deviceId, // existing value
        'sdk': 'flutter', // existing value
        // 'ip': ip, // may be null
        'appVersion': appVersion, // may be null
        'sentAt': sentAt,
        'deviceModel': deviceModel, // 🆕 deviceModel
        'loginTime': loginTime,     // 🆕 Time 
      };
      body.removeWhere((key, value) => value == null);

      final uri = Uri.parse(PixStudioActivationPatch._kWebhookUrl);
      http.Response resp;
      try {
        resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        return 'invalid';
      } catch (_) {
        return 'invalid';
      }

      if (resp.statusCode != 200) {
        return 'invalid';
      }

      final result = (resp.body).trim().toLowerCase();
      if (result != 'allow' && result != 'deny' && result != 'invalid') {
        return 'invalid';
      }

      if (result == 'allow') {
        await PixStudioActivationPatch._secure
            .write(key: PixStudioActivationPatch._kUnlockedKey, value: 'true');
        if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
          await PixStudioActivationPatch._secure.write(
              key: PixStudioActivationPatch._kBoundDeviceKey,
              value: deviceFingerprint);
        }
      }

      return result;
    } catch (_) {
      return 'invalid';
    }
  }
}
