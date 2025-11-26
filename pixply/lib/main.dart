import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pixply/explore/game_creation_store.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pixply/Settings/notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pixply/smoke/animated_circles.dart';
import 'package:pixply/smoke/animation_sequence.dart';
import 'package:pixply/smoke/circle_data.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'Settings/filter_store.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pixply/Likes/like_service.dart';
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:pixply/connected.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pixply/onboarding/onboarding_instructions.dart';
import 'package:pixply/start/welcomepage.dart';
import 'force_update_gate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin localNotifs = FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  try {
    if (Platform.isIOS || Platform.isMacOS) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  await firebaseMessagingBackgroundHandler(message);
  // Show a local notification only for data-only messages to avoid
  // duplicating system notifications for "notification" payloads.
  final n = message.data;
  if (message.notification == null && n.isNotEmpty) {
    final local = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'pixply_channel', 'Pixply Notifications',
      channelDescription: 'Foreground notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n['title'] ?? 'Pixply',
      n['body'] ?? '',
      const NotificationDetails(android: androidDetails),
    );
  }
}

class _FcmTokenManager {
  static const _prefsKey = 'last_fcm_token_sent';
  static bool _initialized = false;

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
    return !offline;
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _sendCurrentIfNeeded();
    FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      await _sendIfChanged(t);
    });
  }

  static Future<void> _sendCurrentIfNeeded() async {
    if (!await _isOnline()) return;
    final t = await FirebaseMessaging.instance.getToken();
    if (t != null) await _sendIfChanged(t);
  }

  static Future<void> _sendIfChanged(String token) async {
    if (!await _isOnline()) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_prefsKey);
    if (last == token) return;
    await FirebaseMessaging.instance.subscribeToTopic('all');
    await prefs.setString(_prefsKey, token);
    if (kDebugMode) {
      print('📌 FCM token (saved): $token');
    }
  }
}
void _openNotificationsScreen() {
  final nav = navigatorKey.currentState;
  if (nav != null) {
    // Avoid stacking multiple Notification screens
    if (notificationsScreenOpen) return;
    nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotificationsScreen());
  }
}
NotifType parseNotifType(String? name) {
  switch ((name ?? 'system').toLowerCase()) {
    case 'game': return NotifType.game;
    case 'studio': return NotifType.studio;
    case 'community': return NotifType.community;
    default: return NotifType.system;
  }
}
Future<void> _saveMessageToStore(RemoteMessage msg) async {
  // از مدل‌ها و استور notification.dart استفاده می‌کنیم
  final store = NotificationStore();
  await store.load();
  final n = IncomingNotification(
    id: msg.messageId ?? DateTime.now().toIso8601String(),
    title: msg.notification?.title ?? '',
    body: msg.notification?.body ?? '',
    type: parseNotifType(msg.data['type'] as String?),
    createdAt: DateTime.now(),
    read: false,
    imageUrl: msg.data['image'] as String?,
  );
  await store.add(n);
}

@pragma('vm:entry-point')
Future<void> _onLocalNotifTapBackground(NotificationResponse response) async {
  // اندروید به entry-point نیاز دارد؛ ناوبری اصلی را در onDidReceive... انجام می‌دهیم
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  try { 
    if (Platform.isIOS || Platform.isMacOS) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    firebaseReady = true;
    await _FcmTokenManager.init();
 } catch (e) {
   if (kDebugMode) {
     debugPrint('Firebase init failed: $e');
   }
 }
  if (firebaseReady) {
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
      FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase Messaging presentation setup failed: $e');
      }
    }
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  await localNotifs.initialize(
  initSettings,
  onDidReceiveNotificationResponse: (NotificationResponse resp) async {
    _openNotificationsScreen();
  },
  onDidReceiveBackgroundNotificationResponse: _onLocalNotifTapBackground,
);

  final androidImpl = localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
  'pixply_channel',            // همین ID که در AndroidNotificationDetails استفاده کردی
  'Pixply Notifications',      // نام کانال برای تنظیمات سیستم
  description: 'Foreground notifications',
  importance: Importance.max,
));

if (firebaseReady) {
FirebaseMessaging.onMessage.listen((msg) async {
  // 1) اول ذخیره شود
  await _saveMessageToStore(msg);

  // 2) بعد نوتیف محلی را نشان بده
  final n = msg.notification;
  if (n != null) {
    const androidDetails = AndroidNotificationDetails(
      'pixply_channel', 'Pixply Notifications',
      channelDescription: 'Foreground notifications',
      importance: Importance.max, priority: Priority.high,
    );
    await localNotifs.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title,
      n.body,
      const NotificationDetails(android: androidDetails),
      payload: (msg.data.isNotEmpty ? msg.data.toString() : null), // اختیاری
    );
  }
});
}


  if (firebaseReady) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        print('FCM TOKEN => ${token ?? 'null'}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token fetch failed: $e');
      }
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
  // هشدار Future را لازم نیست await کنیم
  // ignore: discarded_futures
  setupNotificationListeners(navigatorKey);
});


  final dir = await getApplicationDocumentsDirectory();
  final hiveDir = Directory('${dir.path}/hive');
  if (!await hiveDir.exists()) {
    await hiveDir.create(recursive: true);
  }
  Hive.init(hiveDir.path);
  await Hive.initFlutter();
  await LikeService.initHiveBox();
  await Hive.openBox<Map>('my_creations'); 
  await Hive.openBox('likesBox');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FilterStore()),
        ChangeNotifierProvider(create: (_) => GameCreationStore()),
      ],
    // child: ForceUpdateGate(
    //   remoteJsonUrl: 'https://baharsli.github.io/Pixo-config/app-config.json',
    //   androidStoreUrl: 'https://play.google.com/store/apps/details?id=com.pixply.app',
    //   iosAppStoreUrl: 'https://apps.apple.com/app/idXXXXXXXXX',
      child: const MyApp(),// اپ اصلی
    // ),
  ),
);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: ForceUpdateGate(
        remoteJsonUrl: 'https://baharsli.github.io/Pixo-config/app-config.json',
        androidStoreUrl: 'https://play.google.com/store/apps/details?id=com.pixply.app', // لینک واقعی
        iosAppStoreUrl: 'https://apps.apple.com/app/idXXXXXXXXX',                         // لینک واقعی
        child: const GateScreen(),  // قبلاً همین بود؛ اپ اصلی شما
      ),
    );
  }
}
const String kTermsAcceptedKey = 'pixply_terms_accepted_v1';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> with TickerProviderStateMixin {
  double _logoOpacity = 1.0;
  double _pageOpacity = 1.0;
  bool _offline = false;
  bool _navigated = false;
  late AnimationSequence _animationSequence;
  final _secure = const FlutterSecureStorage(); 
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  
  Future<bool> hasInternet() async {
    try {
      final res = await InternetAddress.lookup('example.com');
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> checkInternetOnce() async {
    final online = await hasInternet();
    if (!mounted) return;
    setState(() => _offline = !online);
  }
 

  @override
  void initState() {
    super.initState();
    checkInternetOnce();

    // Listen to connectivity changes and resume when online
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final isOffline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
      if (isOffline) {
        if (mounted) setState(() => _offline = true);
        return;
      }
      final online = await hasInternet();
      if (!mounted) return;
      if (online) {
        setState(() => _offline = false);
        _resumeIfOnline();
      } else {
        setState(() => _offline = true);
      }
    });

Future<bool> readTermsAccepted() async {
  // ابتدا از SecureStorage بخوان
  final v = await _secure.read(key: kTermsAcceptedKey);
  if (v == 'true' || v == '1') return true;

  // اگر نبود، از SharedPreferences بخوان (fallback)
  final prefs = await SharedPreferences.getInstance();
  final b = prefs.getBool(kTermsAcceptedKey) ?? false;
  return b;
}
Future<void> navigateAfterSplash() async {
  if (!mounted) return;
  _navigated = true;
  // Always go to WelcomePage after splash; it will handle
  // transitioning to onboarding (which requests notification permission),
  // then proceed to the connected page.
  final Widget target = WelcomePage(
    bluetooth: LedBluetooth(),
    isConnected: false,
  );
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(seconds: 1),
      pageBuilder: (_, __, ___) => target,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
    // Generate grayscale animation sequence
    _animationSequence = AnimationSequence(
      sequences: generateGrayscaleCircleSets(8, 5),
      stepDuration: const Duration(seconds: 1),
      onSequenceChange: (index) {
      if (index == 4) {
  Future.delayed(const Duration(seconds: 1), () {
    if (mounted) {
      setState(() {
        _pageOpacity = 0.0;
      });

      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;
        await navigateAfterSplash(); 
      });
    }
  });
}
      },
    );

    // Fade out the logo while animation plays
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _logoOpacity = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void _resumeIfOnline() {
    if (_navigated) return;
    setState(() {
      _pageOpacity = 0.0;
      _logoOpacity = 0.0;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _navigated) return;
      _navigated = true;
      final Widget target = WelcomePage(
        bluetooth: LedBluetooth(),
        isConnected: false,
      );
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(seconds: 1),
          pageBuilder: (_, __, ___) => target,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(seconds: 1),
      opacity: _pageOpacity,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background animation
            AnimatedCircles(sequence: _animationSequence),
            // Centered fading logo
            Center(
              child: AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: _logoOpacity,
                child: SvgPicture.asset(
                  'assets/logo.svg',
                  width: 250,
                  height: 65.93,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (moved dispose() into _GateScreenState)

// Function to generate grayscale animation sequence
List<List<CircleData>> generateGrayscaleCircleSets(int N, int setCount) {
  final List<Color> grayscaleColors = [
    Colors.black,
    Colors.grey[800]!,
    Colors.grey[500]!,
    Colors.grey[300]!,
    Colors.white
  ];
  final random = Random();
  List<List<CircleData>> sequences = [];

  for (int set = 0; set < setCount; set++) {
    List<CircleData> circleSet = [];
    for (int i = 0; i < N; i++) {
      circleSet.add(CircleData(
        id: '$set-$i',
        normalizedPosition: Offset(random.nextDouble(), random.nextDouble()),
        radius: random.nextDouble() * 40 + 20,
        color: grayscaleColors[random.nextInt(grayscaleColors.length)],
      ));
    }
    sequences.add(circleSet);
  }

  return sequences;
}
