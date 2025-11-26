import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

/// مدیریت توکن FCM: دریافت، ارسال به سرور، به‌روزرسانی و حذف
class TokenManager {
  static const _prefsKeyToken = 'last_sent_fcm_token';
  static const _prefsKeyUser  = 'last_sent_user_id';

  final String? userId; // اگر لاگین نداری، می‌تونی null بگذاری و فقط device-level ذخیره کنی
  final String apiBase;  // آدرس API سرورت، مثلا: https://api.example.com

  TokenManager({required this.apiBase, required this.userId});

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
    return !offline;
  }


  /// در شروع اپ صدا بزن: بعد از Firebase.initializeApp و گرفتن مجوز اعلان
  Future<void> init() async {
    // 1) توکن فعلی را بخوان و اگر جدید بود، بفرست
    await _sendCurrentIfNeeded();

    // 2) گوش بده به تغییر توکن‌ها
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _sendToServerIfChanged(newToken);
    });
  }

  /// موقع خروج از حساب/غیرفعال کردن اعلان: توکن را از سرور حذف کن
  Future<void> unregisterToken() async {
    if (!await _isOnline()) return;
    final prefs = await SharedPreferences.getInstance();
    final lastToken = prefs.getString(_prefsKeyToken);
    final lastUser  = prefs.getString(_prefsKeyUser);

    if (lastToken == null) return;

    try {
      // DELETE /push/fcm-token
      final uri = Uri.parse('$apiBase/push/fcm-token');
      final res = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': lastToken,
          'userId': lastUser, // می‌تونی optional نگه داری
        }),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // لوکال را پاک کن
        await prefs.remove(_prefsKeyToken);
        await prefs.remove(_prefsKeyUser);
      } else {
        // می‌تونی لاگ بگیری یا retry داشته باشی
      }
    } catch (_) {
      // لاگ/Retry
    }
  }

  /// ——— private ———

  Future<void> _sendCurrentIfNeeded() async {
    if (!await _isOnline()) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _sendToServerIfChanged(token);
    }
  }

  Future<void> _sendToServerIfChanged(String newToken) async {
    if (!await _isOnline()) return;
    final prefs = await SharedPreferences.getInstance();
    final lastToken = prefs.getString(_prefsKeyToken);
    final lastUser  = prefs.getString(_prefsKeyUser);

    // اگر هیچ تغییری نیست، بی‌خیال
    if (lastToken == newToken && lastUser == (userId ?? '')) {
      return;
    }

    // POST /push/fcm-token
    try {
      final uri = Uri.parse('$apiBase/push/fcm-token');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': newToken,
          'userId': userId,         // اگر لاگین نداری، می‌تونی نفرستی
          'platform': 'android',    // یا 'ios'
          'appVersion': '1.0.0',    // اگر خواستی از PackageInfo پر کن
          'subscribedTopics': ['all'], // اگر از topic استفاده می‌کنی
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        await prefs.setString(_prefsKeyToken, newToken);
        await prefs.setString(_prefsKeyUser, userId ?? '');
      } else {
        // می‌تونی لاگ/Retry داشته باشی
      }
    } catch (_) {
      // لاگ/Retry
    }
  }
}
