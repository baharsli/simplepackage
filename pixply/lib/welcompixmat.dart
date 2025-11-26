
// // welcompixmat_patched.dart
// //
// // Patch: wires the screen to the centralized activation flow without changing UI.

// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:led_ble_lib/led_ble_lib.dart';
// import 'package:pixply/core/activation.dart'; // <-- use the patched activation client
// import 'Settings/termsconditions.dart'; // BrakeConditionPage

// class Welcome extends StatefulWidget {
//   final LedBluetooth bluetooth;
//   final bool isConnected;
//   final String? webhookUrl; // optional override; otherwise service default
//   const Welcome({super.key,    required this.bluetooth,
//     required this.isConnected, this.webhookUrl});

//   @override
//   State<Welcome> createState() => _WelcomeState();
// }

// class _WelcomeState extends State<Welcome> {
//   // ======= UI state (keep design unchanged) =======
//   final TextEditingController _codeCtrl = TextEditingController();
//   bool _submitting = false;
//   int _failedAttemptCount = 0; // consecutive invalid attempts since last lock/success
//   int _lockLevel = 0; // each level adds +5 minutes
//   DateTime? _lockUntil; // when current lock expires
//   Timer? _lockTimer;

//   // ======= Helpers (no UI changes) =======
//   String _normalizeDisplay(String raw) {
//     // returns uppercase grouped by 4 (e.g., XXXX-XXXX-...)
//     final onlyAz09 = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
//     final b = StringBuffer();
//     for (var i = 0; i < onlyAz09.length; i++) {
//       b.write(onlyAz09[i]);
//       if (i % 4 == 3 && i != onlyAz09.length - 1) b.write('-');
//     }
//     return b.toString();
//   }

//   // String _plain16(String raw) =>
//   //     raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

//   Future<void> _handleActivate() async {
//     if (_isLocked) {
//       final rem = _remainingLock;
//       final mm = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
//       final ss = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
//       _showSnack('Please wait $mm:$ss');
//       return;
//     }
//     FocusScope.of(context).unfocus();

//     setState(() => _submitting = true);
//     try {
//       // Use the centralized ActivationService from pixply/core/activation.dart.
//       // It handles code normalization, device/app metadata, and communicates
//       // with the Make.com webhook.  If the user enters a code that is not
//       // exactly 16 alphanumeric characters (after removing separators), the
//       // service will immediately return ActivationResult.invalid.
//       final service = ActivationService(
//         webhookUrl: widget.webhookUrl != null ? Uri.parse(widget.webhookUrl!) : null,
//       );
//       final result = await service.activate(_codeCtrl.text);

//       if (!mounted) return;
//       switch (result) {
//         case ActivationResult.allow:
//           // Code exists in sheet and not yet redeemed: inform success
//           _showSnack('Activation successful.');
//           _failedAttemptCount = 0;
//           _lockLevel = 0;
//           _lockUntil = null;
//           _lockTimer?.cancel();
//           // Navigate to Terms/BrakeConditionPage
//           Navigator.of(context).pushReplacement(
//             MaterialPageRoute(builder: (_) => const BrakeConditionPage()),
//           );
//           break;
//         case ActivationResult.deny:
//           // Duplicate: the code is present but already redeemed
//           _showSnack('The entered code is duplicate or has been used before.');
//           _failedAttemptCount++;
//           if (_failedAttemptCount >= 3) {
//             _beginLock();
//           }
//           break;
//         case ActivationResult.invalid:
//           // Not found in sheet: inform the user that the code is incorrect
//           _showSnack('The entered code is incorrect.');
//           _failedAttemptCount++;
//           if (_failedAttemptCount >= 3) {
//             _beginLock();
//           }
//           break;
//         case ActivationResult.error:
//           _showSnack('Activation service is unavailable. Please try again.');
//           break;
//       }
//     } catch (_) {
//       _showSnack('Unexpected error. Please try again.');
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }

//   void _showSnack(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(msg)),
//     );
//   }

//   bool get _isLocked => _lockUntil != null && DateTime.now().isBefore(_lockUntil!);

//   Duration get _remainingLock =>
//       _isLocked ? _lockUntil!.difference(DateTime.now()) : Duration.zero;

//   void _beginLock() {
//     _lockLevel = (_lockLevel + 1).clamp(1, 1000);
//     final minutes = 5 * _lockLevel;
//     _lockUntil = DateTime.now().add(Duration(minutes: minutes));
//     _failedAttemptCount = 0;
//     _lockTimer?.cancel();
//     _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (!_isLocked) {
//         t.cancel();
//         setState(() {});
//       } else {
//         setState(() {});
//       }
//     });
//     _showSnack('Locked for $minutes minutes');
//     setState(() {});
//   }

//   @override
//   void dispose() {
//     _codeCtrl.dispose();
//     _lockTimer?.cancel();
//     super.dispose();
//   }

//   // ======= UI layout (design-only changes) =======
//   @override
//   Widget build(BuildContext context) {
//     // If you already have the full UI, you can ignore this minimal preview and
//     // wire _codeCtrl and _handleActivate into your existing widgets.
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Center(
//           child: SizedBox(
//             width: 360, // fixed content width
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 const SizedBox(height: 24),
//                 // Title at top (English)
//                 const Text(
//                   'Activate',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                     fontFamily: 'Poppins',
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 16),
//                 // Image under the title with exact size 340x203
//                 SvgPicture.asset(
//                   'assets/activatecart.svg',
//                   width: 340,
//                   height: 203,
//                   fit: BoxFit.contain,
//                 ),
//                 const SizedBox(height: 16),
//                 // One-line instruction (English)
//                 const Text(
//                   'Please enter your activation code',
//                   style: TextStyle(color: Colors.white70, fontSize: 14 , fontFamily: 'Poppins'),
//                   textAlign: TextAlign.center,
//                 ),
//                 if (_isLocked) ...[
//                   const SizedBox(height: 8),
//                   Builder(
//                     builder: (_) {
//                       final rem = _remainingLock;
//                       final mm = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
//                       final ss = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
//                       return Text(
//                         'Try again in $mm:$ss',
//                         style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Poppins'),
//                       );
//                     },
//                   ),
//                 ],
//                 const SizedBox(height: 12),
//                 // Input for code with exact height and width
//                 SizedBox(
//                   width: 340,
//                   height: 48,
//                   child: TextField(
//                     controller: _codeCtrl,
//                     textCapitalization: TextCapitalization.characters,
//                     style: const TextStyle(color: Colors.white, fontSize: 16),
//                     cursorColor: Colors.white70,
//                     enabled: !_isLocked,
//                     onChanged: (v) {
//                       final norm = _normalizeDisplay(v);
//                       if (norm == v) return;

//                       // Keep caret after the same count of plain A-Z0-9 chars
//                       // even when dashes are inserted (every 4 chars).
//                       final sel = _codeCtrl.selection.baseOffset;
//                       int plainBefore = 0;
//                       if (sel > 0) {
//                         final reg = RegExp(r'[A-Za-z0-9]');
//                         for (var i = 0; i < sel && i < v.length; i++) {
//                           if (reg.hasMatch(v[i])) plainBefore++;
//                         }
//                       }
//                       final hyphBefore = plainBefore > 0 ? (plainBefore - 1) ~/ 4 : 0;
//                       var newOffset = plainBefore + hyphBefore;
//                       if (newOffset > norm.length) newOffset = norm.length;

//                       _codeCtrl.value = TextEditingValue(
//                         text: norm,
//                         selection: TextSelection.collapsed(offset: newOffset),
//                       );
//                     },
//                     decoration: InputDecoration(
//                       labelText: 'Activation Code',
//                       hintText: 'XXXX-XXXX-XXXX-XXXX',
//                       labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
//                       hintStyle: const TextStyle(color: Colors.white38 , fontFamily: 'Poppins'),
//                       filled: true,
//                       fillColor: Colors.white10,
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10),
//                         borderSide: const BorderSide(color: Colors.white24),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10),
//                         borderSide: const BorderSide(color: Colors.white70),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 // Send code button with specified color and exact size
//                 SizedBox(
//                   width: 340,
//                   height: 48,
//                   child: ElevatedButton(
//                     onPressed: (!_isLocked && !_submitting) ? _handleActivate : null,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color.fromRGBO(189, 255, 0, 1),
//                       foregroundColor: Colors.black,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: _submitting
//                         ? const SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//                             ),
//                           )
//                         : const Text('Send Code', style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             fontFamily: 'Poppins',
//                           ),
//                           ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
