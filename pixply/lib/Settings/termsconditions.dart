
// import 'dart:io';
// import 'package:flutter/material.dart';
// // import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:led_ble_lib/led_ble_lib.dart';
// import 'package:pixply/connected.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pixply/onboarding/onboarding_instructions.dart';
// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// // Added for retrieving device information
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter/gestures.dart';
// // Notification permission requests are handled centrally in ConnectedPage.

// class BrakeConditionPage extends StatefulWidget {
//   const BrakeConditionPage({super.key});

//   @override
//   State<BrakeConditionPage> createState() => _BrakeConditionPageState();
// }
// const String kTermsAcceptedKey = 'pixply_terms_accepted_v1';
// const String kUserIdKey = 'pixply_user_id';
// const String kWebhookUrl = 'https://hook.eu2.make.com/j798ph0qy57ab49kucld3b7r9hm8f2by';
// // Webhook API key (Make.com Webhooks > Advanced > Keychain)
// const String kWebhookApiKey = 'Lm6t@9kQpj#';
// // Header name used by Make for API key verification. If your Make webhook
// // expects a different header (e.g., 'X-IMT-Execution-Key'), change this name.
// const String kWebhookApiHeader = 'X-Api-Key';

// class _BrakeConditionPageState extends State<BrakeConditionPage> {

//   Future<bool> _shouldShowOnboarding() async {
//     final prefs = await SharedPreferences.getInstance();
//     final seenVersion = prefs.getInt(OnboardingScreen.kPrefsKey) ?? 0;
//     return seenVersion != OnboardingScreen.kVersion;
//   }


//   Future<String> _getOrCreateUserId() async {
//   // یک شناسه پایدار در SecureStorage؛ اگر نبود می‌سازیم
//   String? uid = await _secure.read(key: kUserIdKey);
//   if (uid != null && uid.isNotEmpty) return uid;

//   // بدون وابستگی جدید، یک شناسه تصادفی معقول تولید می‌کنیم
//   uid = _randomId();
//   await _secure.write(key: kUserIdKey, value: uid);
//   return uid;
// }

// String _randomId({int len = 24}) {
//   const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
//   final rnd = Random.secure();
//   return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
// }

  
//   final List<Map<String, String>> _items = const [
//     {
//       "title": "1. About These Terms",
//       "subtitle":
//           "These Terms & Conditions (\"Terms\") govern your use of the Pixply mobile app, Pixply devices (hardware), and related services offered by Pixply Ltd (\"Pixply\", \"we\"). By using Pixply, you agree to these Terms and to any policies referenced here (e.g., Privacy Policy, Return & Refund Policy). Nothing in these Terms limits your mandatory consumer rights under applicable law."
//     },
//     {
//       "title": "2. Eligibility (Age & Regions)",
//       "subtitle":
//           "• You must be at least 13 to use the app in most countries.\n• In the European Economic Area (EEA), if you are under your country’s digital-consent age (between 13 and 16), a parent/guardian must provide verifiable consent for any processing of your personal data.\n• We do not knowingly permit children under 13 to use Pixply where COPPA or similar rules apply.\n• Business/educational use must ensure all end users meet local age rules."
//     },
//     {
//       "title": "3. Acceptable Use & User Content",
//       "subtitle":
//           "You agree not to: (a) use Pixply for illegal, harmful, or deceptive activity; (b) upload or share unlawful, infringing, hateful, or sexually explicit content; (c) interfere with or reverse-engineer Pixply; (d) commercially exploit Pixply except as expressly permitted.\nIf the app allows uploads/sharing, you retain your rights in your content and grant Pixply a limited licence to host and display it for the service. We may remove or restrict content that breaches these Terms or law.\nNotice & Appeal (DSA): you may report illegal or policy-breaching content via in-app reporting; we will assess notices diligently and provide reasons for removal/restriction with a way to appeal."
//     },
//     {
//       "title": "4. Intellectual Property",
//       "subtitle":
//           "Pixply software, designs, and content are owned by Pixply Ltd or its licensors. We grant you a personal, non-transferable, revocable licence to use the app and firmware solely as provided. Do not copy, modify, distribute, or create derivative works except where permitted by law."
//     },
//     {
//       "title": "5. Purchases, Pricing, and Taxes",
//       "subtitle":
//           "• Hardware and paid services/features may be sold via our website (e.g., Shopify) or in-app.\n• Prices may change; applicable taxes, duties, and shipping may apply.\n• Orders are subject to acceptance; we may reject/refund orders for legitimate reasons (e.g., suspected fraud, inventory constraints)."
//     },
//     {
//       "title": "6. Right of Withdrawal (EEA/UK Distance Sales)",
//       "subtitle":
//           "If you are an EEA/UK consumer purchasing hardware at a distance, you have a 14-day right to withdraw without giving any reason. The period starts when you (or a third party indicated by you) receive the goods. To exercise your right, notify us within 14 days (email is fine) and return the goods within 14 days of notifying us. Unless we state otherwise, you bear return shipping costs. We will refund the price (and the standard outbound delivery cost, if charged) within 14 days of receiving the returned goods or proof of return. You are responsible for any diminished value resulting from handling beyond what is necessary to establish the nature, characteristics, and functioning of the goods. Local statutory variations apply."
//     },
//     {
//       "title": "7. Exceptions & Digital Content",
//       "subtitle":
//           "Your 14-day withdrawal right may not apply to: (a) sealed goods not suitable for return due to health protection or hygiene reasons once unsealed; (b) goods made to your specifications or clearly personalised; (c) digital content not supplied on a tangible medium once delivery has begun after your express consent and acknowledgment that you lose the right of withdrawal."
//     },
//     {
//       "title": "8. Statutory Guarantees & Repairs",
//       "subtitle":
//           "EEA: Hardware benefits from a legal guarantee of conformity for at least two years from delivery; remedies may include repair, replacement, price reduction, or reimbursement, depending on law and the specific defect.\nUK: Your statutory rights under the Consumer Rights Act 2015 apply to goods, digital content, and services. These rights exist in addition to any commercial warranty we may offer."
//     },
//     {
//       "title": "9. Subscriptions & Auto-Renew (if offered)",
//       "subtitle":
//           "If you subscribe to paid features (e.g., PixStudio), the plan term, price, renewal frequency, and cancellation method will be shown at purchase. Subscriptions auto-renew unless you cancel before the renewal date. We’ll tell you how to cancel (in-app or via the platform). Trials convert to paid unless cancelled on time. Where required, we provide reminders and easy cancellation options."
//     },
//     {
//       "title": "10. Firmware, Software Updates & Connectivity",
//       "subtitle":
//           "We may deliver updates (including security patches, bug fixes, or feature changes). Some features require Bluetooth/Internet; performance may vary by device and environment. Do not use the device in unsafe conditions or in ways that could cause injury or property damage."
//     },
//     {
//       "title": "11. Privacy & Data Protection",
//       "subtitle":
//           "Your data is processed in accordance with our Privacy Policy (see app/website). It explains purposes, legal bases, retention, and your rights (access, deletion, objection, portability, etc.). For EEA/UK users, GDPR/UK-GDPR rights apply. For US users, COPPA restrictions apply for children under 13 where relevant. Contact support@pixply.io for data requests."
//     },
//     {
//       "title": "12. Limitation of Liability",
//       "subtitle":
//           "Pixply is provided \"as is\" and \"as available\". To the maximum extent permitted by law, we are not liable for indirect or consequential losses (e.g., loss of data, profits). Our total liability for any loss arising in connection with the service or a product is limited to the amount you paid in the 12 months preceding the event.\nNothing excludes or limits liability for death or personal injury caused by negligence, fraud, fraudulent misrepresentation, or any liability that cannot be excluded under applicable consumer law. Your statutory rights remain unaffected."
//     },
//     {
//       "title": "13. Governing Law, Jurisdiction & Consumer Rights",
//       "subtitle":
//           "These Terms are governed by the laws of England & Wales. If you are a consumer resident in the EEA/UK, you also benefit from any mandatory protections of your country of residence and may bring proceedings in your local courts where required by law."
//     },
//     {
//       "title": "14. Complaints, Dispute Resolution & Changes",
//       "subtitle":
//           "If you have a complaint, contact support@pixply.io. We will try to resolve issues amicably. The former EU Online Dispute Resolution (ODR) platform has been discontinued (20 July 2025). Where available, you may access local Alternative Dispute Resolution (ADR) bodies or consumer authorities. We may update these Terms from time to time; material changes will be notified in-app or on our website. Continued use after changes means you accept the updated Terms."
//     },
// {
//   "title": "15. Company Details & Contact",
//   "subtitle":
//       "Pixply Ltd\nRegistered office: Office One, 1 Coldbath Square, Farringdon, London, United Kingdom, EC1R 5HL\nContact: contact@pixply.io\nSupport: support@pixply.io\nWebsite: www.pixply.io\nIf you purchase from our online store, please also see the Returns, Warranty, and Privacy pages linked there."
// },

//   ];

//   // وضعیت تیک هر قانون
//   late List<bool> _checks;
//   bool _agreeAll = false;

//   // ✅ اضافه: ذخیره امن وضعیت تایید
//   final _secure = const FlutterSecureStorage();

//   // ✅ اضافه: قوانین اجبا
//   final Set<int> _required = {
//     0, 2, 3, 4, 6, 7, 9, 10, 13
//   };

//   // Informational sections without a checkbox
//   // 16. Company Details & Contact -> index 15 (0-based)
//   final Set<int> _noCheckbox = {14};

//   // ✅ اضافه: ایندکس‌های خطادار برای نمایش آیکن اخطار
//   final Set<int> _errors = {};

//   // ✅ اضافه: جلوگیری از دوبار کلیک
//   bool _submitting = false;

//   @override
//   void initState() {
//     super.initState();
//     _checks = List<bool>.filled(_items.length, false);
//     _agreeAll = false;
//   }

//   // ✅ اضافه: چک اینترنت
//   Future<bool> _hasInternet() async {
//     try {
//       final res = await InternetAddress.lookup('example.com')
//           .timeout(const Duration(seconds: 3));
//       return res.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }

//   // ---------------------------------------------------------------------------
//   // Additional helpers to collect device IP and model
//   // These functions are invoked when submitting the consent form. They attempt
//   // to fetch the external (public) IP address and the underlying device model
//   // information. The IP is fetched via a simple HTTP API (https://api.ipify.org).
//   // The device model is retrieved using the device_info_plus plugin, which must
//   // be added to your pubspec.yaml. If device_info_plus is not available on a
//   // platform, or if any call fails, sensible fallbacks are returned.

//   /// Returns the device's public IP address as reported by api.ipify.org.
//   Future<String?> _getPublicIp() async {
//     try {
//       final response = await http
//           .get(Uri.parse('https://api.ipify.org?format=json'))
//           .timeout(const Duration(seconds: 5));
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         return data['ip'] as String?;
//       }
//     } catch (_) {
//       // ignore; will return null
//     }
//     return null;
//   }

//   /// Returns a human‑readable model name for the current device.
//   Future<String> _getDeviceModel() async {
//     try {
//       final deviceInfo = DeviceInfoPlugin();
//       if (Platform.isAndroid) {
//         final android = await deviceInfo.androidInfo;
//         final model = android.model;
//         final manufacturer = android.manufacturer;
//         if (manufacturer != null && model != null) {
//           return '$manufacturer $model';
//         }
//         return model ?? manufacturer ?? 'Android';
//       } else if (Platform.isIOS) {
//         final ios = await deviceInfo.iosInfo;
//         final name = ios.name;
//         final model = ios.model;
//         // utsname.machine contains codes like "iPhone13,4"; prefer human name if available
//         return name != null && name.isNotEmpty ? name : (model ?? 'iOS');
//       } else {
//         // Fallback for other platforms (web, Fuchsia, etc.)
//         return Platform.operatingSystem;
//       }
//     } catch (_) {
//       // If anything fails, fall back to OS name
//       return Platform.operatingSystem;
//     }
//   }

//   // ✅ اضافه: شبیه‌سازی ارسال به سرور (بعداً API واقعی‌ت رو اینجا بزن)
// Future<void> _sendConsentToServer({
//   required Map<String, dynamic> payload,
// }) async {
//   final resp = await http
//       .post(
//         Uri.parse(kWebhookUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           kWebhookApiHeader: kWebhookApiKey,
//           // Some Make configurations expect this legacy header name; harmless if ignored.
//           'X-IMT-Execution-Key': kWebhookApiKey,
//         },
//         body: jsonEncode(payload),
//       )
//       .timeout(const Duration(seconds: 10));

//   // کدهای 2xx موفق هستند
//   if (resp.statusCode < 200 || resp.statusCode >= 300) {
//     throw Exception('submit_failed');
//   }
// }


//   // ✅ اضافه: منطق نهایی دکمه
// Future<void> _onAgree() async {
//   if (_submitting) return;
//   _submitting = true;

//   // Require single consent checkbox
//   if (!_agreeAll) {
//     _submitting = false;
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("Please check the box to agree to all rules."),
//         duration: Duration(seconds: 2),
//       ),
//     );
//     return;
//   }

//   // 1) اینترنت
//   final online = await _hasInternet();
//   if (!online) {
//     _submitting = false;
//     if (!mounted) return;
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: const Color(0xFF202020),
//         title: const Text("Internet connection required",
//             style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 16)),
//         content: const Text(
//           "To confirm the rules, please connect to the Internet.",
//           style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontWeight: FontWeight.w400, fontSize: 14),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("OK",
//                 style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w400, fontSize: 16)),
//           ),
//         ],
//       ),
//     );
//     return;
//   }

//   // 2) اعتبارسنجی قوانین اجباری
//   if (_agreeAll) {
//     for (int i = 0; i < _checks.length; i++) {
//       if (_noCheckbox.contains(i)) continue;
//       _checks[i] = true;
//     }
//   }
//   _errors.clear();
//   for (int i = 0; i < _checks.length; i++) {
//     if (_noCheckbox.contains(i)) continue; // skip informational sections
//     if (_required.contains(i) && _checks[i] == false) {
//       _errors.add(i);
//     }
//   }
//   if (_errors.isNotEmpty) {
//     _submitting = false;
//     if (!mounted) return;
//     setState(() {}); // نمایش آیکن‌های اخطار
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("To continue, check all mandatory rules."),
//         duration: Duration(seconds: 2),
//       ),
//     );
//     return;
//   }

//   // 3) ساخت payload برای وبهوک
//   // With single consent, mark all non-informational items as checked
//   if (_agreeAll) {
//     for (int i = 0; i < _checks.length; i++) {
//       if (_noCheckbox.contains(i)) continue;
//       _checks[i] = true;
//     }
//   }

//   final userId = await _getOrCreateUserId();
//   final nowIso = DateTime.now().toIso8601String();
//   final localeTag = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
//   final platform = Theme.of(context).platform.name; // android/ios/fuchsia

//   final List<Map<String, dynamic>> acceptedItems = [];
//   final List<Map<String, dynamic>> declinedItems = [];

//   for (int i = 0; i < _items.length; i++) {
//     if (_noCheckbox.contains(i)) {
//       // Do not include informational entries in accepted/declined lists
//       continue;
//     }
//     final entry = {
//       'index': i,
//       'title': _items[i]['title'],
//     };
//     if (_checks[i]) {
//       acceptedItems.add(entry);
//     } else {
//       declinedItems.add(entry);
//     }
//   }

//   // Fetch IP address and device model concurrently. The calls begin now
//   // so they can run while the accepted/declined lists are being built. They
//   // complete just before constructing the final payload.
//   // final ipFuture = _getPublicIp();
//   final modelFuture = _getDeviceModel();
//   // final ipAddress = await ipFuture;
//   final deviceModel = await modelFuture;

//   final payload = {
//     'event': 'terms_consent',
//     'user_id': userId,
//     'timestamp': nowIso,
//     'locale': localeTag,
//     'platform': platform,
//     'device_model': deviceModel,
//     // 'ip_address': ipAddress,
//     'app_area': 'termsconditions.dart',
//     'accepted_required': true,
//     'accepted_all': true, // چون همه‌ی اجباری‌ها تیک خورده‌اند
//     'accepted_items': acceptedItems,
//     'declined_items': declinedItems,
//     // اگر لازم داری توکن یا ایمیل کاربر را اضافه کنی، می‌توانی در اینجا بیافزایی.
//   };

//   // 4) ارسال به وبهوک
//   try {
//     await _sendConsentToServer(payload: payload);

//     // 5) ذخیره وضعیت تایید
//     await _secure.write(key: kTermsAcceptedKey, value: 'true');
//     await _secure.write(key: 'terms_accepted_at', value: nowIso);

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(kTermsAcceptedKey, true);
//   } catch (_) {
//     _submitting = false;
//     if (!mounted) return;
//     // اگر ارسال به هر دلیل شکست بخورد، اجازه‌ی ادامه نمی‌دهیم
//     // (در صورت تمایل می‌توانی اجازه دهی و فقط هشدار بدهی)
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: const Color(0xFF2A2A2A),
//         title: const Text("Submit failed", style: TextStyle(color: Colors.white)),
//         content: const Text(
//           "Could not record your consent. Please try again.",
//           style: TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
//         ],
//       ),
//     );
//     return;
//   } finally {
//     _submitting = false;
//   }

//   // 6) ورود به صفحه اصلی
//   if (!mounted) return;
//   final showOnboarding = await _shouldShowOnboarding();
//   Navigator.of(context).pushReplacement(
//     MaterialPageRoute(
//       builder: (_) => showOnboarding
//           ? const OnboardingScreen()
//           : ConnectedPage(
//               bluetooth: LedBluetooth(),
//               isConnected: false,
//             ),
//     ),
//   );

//   // Removed duplicate notification permission prompt to avoid double dialogs.
// }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Stack(
//             children: [
//               ListView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 padding: const EdgeInsets.only(bottom: 140),
//                 children: [
//                   Directionality(
//                     textDirection: TextDirection.ltr,
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Material(
//                           // color: const Color(0xFF333333),
//                           // shape: const CircleBorder(),
//                           // child: InkWell(
//                           //   customBorder: const CircleBorder(),
//                           //   onTap: () async {
//                           //     await Navigator.maybePop(context);
//                           //   },
//                             // child: SizedBox(
//                             //   width: 71,
//                             //   height: 71,
//                             //   child: Center(
//                             //     child: SvgPicture.asset(
//                             //       "assets/back.svg",
//                             //       width: 35,
//                             //       height: 35,
//                             //       colorFilter: const ColorFilter.mode(
//                             //           Colors.white, BlendMode.srcIn),
//                             //     ),
//                             //   ),
//                             // ),
//                           // ),
//                         // ),
//                         const SizedBox(width: 14),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Terms & Conditions",
//                                 textAlign: TextAlign.left,
//                                 style: TextStyle(
//                                   fontSize: 24,
//                                   fontWeight: FontWeight.w600,
//                                   fontFamily: 'Poppins',
//                                   color: Colors.white,
//                                 ),
//                                 softWrap: true,
//                                 maxLines: null,
//                               ),
//                               SizedBox(height: 8),
//                               Text(
//                                 "Last updated: 9 October 2025",
//                                 textAlign: TextAlign.left,
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Color.fromARGB(255, 255, 255, 255),
//                                   fontWeight: FontWeight.w400,
//                                   fontFamily: 'Poppins',
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),

//                   // لیست قوانین + چک‌باکس کنار هرکدام (بدون تغییر استایل متن‌ها)
//                   ListView.separated(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: _items.length,
//                     separatorBuilder: (context, i) =>
//                         const SizedBox(height: 12),
//                     itemBuilder: (context, index) {
//                       final item = _items[index];
//                       final isRequired = _required.contains(index);
//                       final showCheckbox = false; // disable per-item checkbox
//                       final showError = false;

//                       return _ListItem(
//                         title: item['title'] ?? '',
//                         subtitle: item['subtitle'] ?? '',
//                         checked: _checks[index],
//                         showCheckbox: showCheckbox,
//                         isRequired: isRequired,
//                         showError: showError,
//                         onChanged: (v) async {
//                           if (!showCheckbox) return;
//                           // اگر می‌خواهی بدون اینترنت حتی تیک هم نخورد، این بلوک را آن‌کامنت کن:
//                           /*
//                           if (!await _hasInternet()) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text("برای تیک‌زدن قوانین باید آنلاین باشید."),
//                                 duration: Duration(seconds: 2),
//                               ),
//                             );
//                             return;
//                           }
//                           */
//                           setState(() => _checks[index] = v ?? false);
//                         },
//                       );
//                     },
//                   ),
//                   // Agree-all checkbox placed at the end of the rules
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8.0),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Checkbox(
//                           value: _agreeAll,
//                           onChanged: (v) => setState(() => _agreeAll = v ?? false),
//                           activeColor: Colors.white,
//                           checkColor: Colors.black,
//                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           visualDensity: VisualDensity.compact,
//                         ),
//                         const SizedBox(width: 6),
//                         const Expanded(
//                           child: Text(
//                             "I agree to all rules",
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.white,
//                               fontWeight: FontWeight.w500,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                 ],
//               ),

//               // دکمه پایین: منطق جدید
//               Positioned(
//                 left: 0,
//                 right: 0,
//                 bottom: 20,
//                 child: Container(
//                   margin: const EdgeInsets.symmetric(horizontal: 20),
//                   height: 82,
//                   decoration: BoxDecoration(
//                     color: const Color.fromRGBO(49, 49, 49, 1),
//                     borderRadius: BorderRadius.circular(41),
//                   ),
//                   child: TextButton(
//                     onPressed: _onAgree,
//                     child: const Center(
//                       child: Text(
//                         "I agree to the Pixply Terms & Conditions",
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w400,
//                           fontFamily: 'Poppins',
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _CompanyDetailsRich extends StatelessWidget {
//   final String subtitle;
//   const _CompanyDetailsRich({required this.subtitle});

//   Future<void> _open(Uri uri) async {
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri, mode: LaunchMode.externalApplication);
//     }
//   }

//   TextSpan _linkSpan(String text, String url) {
//     return TextSpan(
//       text: text,
//       style: const TextStyle(
//         color: Colors.blueAccent,
//         decoration: TextDecoration.underline,
//         fontFamily: 'Poppins',
//       ),
//       recognizer: (TapGestureRecognizer()..onTap = () => _open(Uri.parse(url))),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // خطوط subtitle را جدا می‌کنیم تا هر خط را جداگانه بسازیم
//     final lines = subtitle.split('\n');

//     // مقادیر را از خطوط پیدا می‌کنیم
//     String? addressLine;
//     String? contactEmail;
//     String? supportEmail;
//     String? website;

//     for (final line in lines) {
//       final l = line.trim();
//       if (l.toLowerCase().startsWith('registered office:')) {
//         addressLine = l.substring('registered office:'.length).trim();
//       } else if (l.toLowerCase().startsWith('contact:')) {
//         contactEmail = l.substring('contact:'.length).trim();
//       } else if (l.toLowerCase().startsWith('support:')) {
//         supportEmail = l.substring('support:'.length).trim();
//       } else if (l.toLowerCase().startsWith('website:')) {
//         website = l.substring('website:'.length).trim();
//       }
//     }

//     // URLهای نهایی
//     final mapsUrl = addressLine == null
//         ? null
//         : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addressLine!)}';
//     final contactUrl = contactEmail == null ? null : 'mailto:$contactEmail';
//     final supportUrl = supportEmail == null ? null : 'mailto:$supportEmail';
//     final siteUrl = (website == null)
//         ? null
//         : (website!.startsWith('http') ? website! : 'https://${website!}');

//     // استایل متن عادی
//     const base = TextStyle(
//       fontSize: 14,
//       color: Colors.white,
//       fontFamily: 'Poppins',
//       fontWeight: FontWeight.w400,
//       height: 1.7,
//     );

//     // بدنه: RichText با خطوط لینک‌دار
//     return RichText(
//       text: TextSpan(
//         style: base,
//         children: [
//           const TextSpan(text: 'Pixply Ltd\n'),
//           if (addressLine != null) ...[
//             const TextSpan(text: 'Registered office: '),
//             if (mapsUrl != null)
//               _linkSpan(addressLine!, mapsUrl)
//             else
//               TextSpan(text: addressLine!),
//             const TextSpan(text: '\n'),
//           ],
//           // این‌ها را از subtitle اصلی هم نگه می‌داریم
//           // اگر Company number / VAT مقدار ندارند، همان — نمایش داده می‌شوند
//           // برای حفظ ترتیب، دوباره از lines می‌خوانیم و فقط مواردی که لینک دارند را جایگزین می‌کنیم
//           ...lines.where((l) =>
//                   !l.toLowerCase().startsWith('pixply ltd') &&
//                   !l.toLowerCase().startsWith('registered office:') &&
//                   !l.toLowerCase().startsWith('contact:') &&
//                   !l.toLowerCase().startsWith('support:') &&
//                   !l.toLowerCase().startsWith('website:') &&
//                   l.isNotEmpty)
//               .map((l) => TextSpan(text: '$l\n')),

//           if (contactEmail != null) ...[
//             const TextSpan(text: 'Contact: '),
//             _linkSpan(contactEmail!, contactUrl!),
//             const TextSpan(text: '\n'),
//           ],
//           if (supportEmail != null) ...[
//             const TextSpan(text: 'Support: '),
//             _linkSpan(supportEmail!, supportUrl!),
//             const TextSpan(text: '\n'),
//           ],
//           if (website != null) ...[
//             const TextSpan(text: 'Website: '),
//             _linkSpan(website!, siteUrl!),
//             const TextSpan(text: '\n'),
//           ],

//           // هرچه در انتهای subtitle آمده (راهنما/توضیح فروشگاه) را هم نشان بده
//           // پیدا کردن خط توضیح فروشگاه:
//           ...lines
//               .where((l) => l.toLowerCase().startsWith('if you purchase from'))
//               .map((l) => TextSpan(text: l)),
//         ],
//       ),
//     );
//   }
// }


// class _ListItem extends StatelessWidget {
//   final String title;
//   final String subtitle;
//   final bool checked;
//   final bool showCheckbox;
//   final bool isRequired;   // ✅ اضافه
//   final bool showError;    // ✅ اضافه
//   final ValueChanged<bool?> onChanged;

//   const _ListItem({
//     required this.title,
//     required this.subtitle,
//     required this.checked,
//     required this.showCheckbox,
//     required this.onChanged,
//     required this.isRequired,
//     required this.showError,
//   });

//   @override
//   Widget build(BuildContext context) {
//       final bool isCompanySection = title.trim().startsWith('15. Company Details');
//     final bool shouldAutoLink = title.trim().startsWith('11.') || title.trim().startsWith('14.');

//     final Widget subtitleWidget = (!showCheckbox && isCompanySection)
//         ? _CompanyDetailsRich(subtitle: subtitle)
//         : shouldAutoLink
//             ? _AutoLinkText(
//                 text: subtitle,
//                 baseStyle: const TextStyle(
//                   fontSize: 14,
//                   color: Color.fromARGB(255, 255, 255, 255),
//                   fontFamily: 'Poppins',
//                   fontWeight: FontWeight.w400,
//                   height: 1.7,
//                 ),
//                 linkStyle: const TextStyle(
//                   color: Colors.blueAccent,
//                   decoration: TextDecoration.underline,
//                   fontFamily: 'Poppins',
//                 ),
//               )
//             : Text(
//                 subtitle,
//                 textAlign: TextAlign.left,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Color.fromARGB(255, 255, 255, 255),
//                   fontFamily: 'Poppins',
//                   fontWeight: FontWeight.w400,
//                   height: 1.7,
//                 ),
//               );

//     return Container(
//       padding: const EdgeInsets.all(14),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ردیف تیتر + چک‌باکس (تیتر همان استایل قبلی را حفظ کرده)
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               if (showCheckbox) ...[
//                 Checkbox(
//                   value: checked,
//                   onChanged: onChanged,
//                   activeColor: Colors.white,
//                   checkColor: Colors.black,
//                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                   visualDensity: VisualDensity.compact,
//                 ),
//                 const SizedBox(width: 6),
//               ],
//               Expanded(
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Expanded(
//                       child: Text(
//                         title + ((isRequired && showCheckbox) ? " *" : ""),
//                         textAlign: TextAlign.left,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                           fontFamily: 'Poppins',
//                           color: Colors.white,
//                         ),
//                         maxLines: null,
//                         softWrap: true,
//                       ),
//                     ),
//                     // ✅ آیکن اخطار فقط وقتی لازم باشد
//                     if (isRequired && showCheckbox && showError) ...[
//                       const SizedBox(width: 6),
//                       const Icon(Icons.error_outline,
//                           color: Colors.redAccent, size: 18),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//           ),
//          const SizedBox(height: 8),
//          subtitleWidget,


//         ],
//       ),
//     );
//   }
// }

// // Generic auto-link text (emails and URLs)
// class _AutoLinkText extends StatelessWidget {
//   final String text;
//   final TextStyle baseStyle;
//   final TextStyle linkStyle;

//   const _AutoLinkText({
//     required this.text,
//     required this.baseStyle,
//     required this.linkStyle,
//   });

//   Future<void> _open(Uri uri) async {
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri, mode: LaunchMode.externalApplication);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final spans = <InlineSpan>[];
//     final pattern = RegExp(r"(https?://[^\s]+|www\.[^\s]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})");

//     int index = 0;
//     for (final m in pattern.allMatches(text)) {
//       if (m.start > index) {
//         spans.add(TextSpan(text: text.substring(index, m.start)));
//       }
//       final matchText = m.group(0)!;
//       Uri uri;
//       if (matchText.contains('@') && !matchText.contains('://')) {
//         uri = Uri(scheme: 'mailto', path: matchText);
//       } else {
//         final url = matchText.startsWith('http') ? matchText : 'https://$matchText';
//         uri = Uri.parse(url);
//       }
//       spans.add(TextSpan(
//         text: matchText,
//         style: linkStyle,
//         recognizer: (TapGestureRecognizer()..onTap = () { _open(uri); }),
//       ));
//       index = m.end;
//     }
//     if (index < text.length) {
//       spans.add(TextSpan(text: text.substring(index)));
//     }

//     return RichText(text: TextSpan(style: baseStyle, children: spans));
//   }
// }




