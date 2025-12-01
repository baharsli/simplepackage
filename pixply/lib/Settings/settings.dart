// Combined Settings Page UI with Bluetooth, Brightness, Orientation, and Reset
import 'package:flutter/material.dart';
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pixply/Settings/color_config.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:pixply/games.dart';
import 'package:pixply/Settings/rotation_config.dart' ;
import 'package:pixply/Likes/like.dart';
import 'package:pixply/explore/explore.dart';
// import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'dart:math' as math;

class SettingsPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;

  const SettingsPage({super.key, required this.bluetooth, required this.isConnected});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool resetDefault = false;
  double brightness = 0.5;
  double orientation = 0;
  Color selectedColor = ColorConfig.selectedDisplayColor;
  ScreenRotation _selectedRotation = ScreenRotation.degree0;
  // bool _rotating = false;
  // double _turns = 0.0;

  // ScreenRotation _toDeviceRotation(ScreenRotation r) {
  //   return RotationStore.toDeviceRotation(r);
  // }


//   int _rotToDeg(ScreenRotation r) {
//   switch (r) {
//     case ScreenRotation.degree0: return 0;
//     case ScreenRotation.degree90: return 90;
//     case ScreenRotation.degree180: return 180;
//     case ScreenRotation.degree270: return 270;
//   }
// }

// ScreenRotation _degToRot(int d) {
//   final x = ((d % 360) + 360) % 360;
//   if (x == 90) return ScreenRotation.degree90;
//   if (x == 180) return ScreenRotation.degree180;
//   if (x == 270) return ScreenRotation.degree270;
//   return ScreenRotation.degree0;
// }

// Future<void> _applyRotation(int delta) async {
//   if (_rotating) return;
//   _rotating = true;

//   final newDeg = (_rotToDeg(_selectedRotation) + delta) % 360;
//   final next = _degToRot(newDeg);
//   // final newDeg = _rotToDeg(_selectedRotation) + delta;
//   // final next = _degToRot(newDeg);

//   setState(() => _selectedRotation = next);
// //   setState(() {
// //   _selectedRotation = next;
// //   _turns = _rotToDeg(next) / 360.0; // هر بار فقط 1/4 دور در همان جهت
// // });
  

//   if (widget.isConnected) {
//     try {
//       await widget.bluetooth.setRotation(next);
//       // await widget.bluetooth.setRotation(_toDeviceRotation(next));
//       await Future.delayed(const Duration(milliseconds: 220));
//       RotationStore.setRotation(next);
//       await DisplayManager.refreshDisplay();
//     } catch (_) {
//       // if setting rotation fails, revert to previous
//       // setState(() => _selectedRotation = _degToRot(_rotToDeg(_selectedRotation) - delta));
//       if (!mounted) return;
//       setState(() => _selectedRotation = _degToRot(_rotToDeg(_selectedRotation) - delta));
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to set rotation')),
//       ); // SnackBar  
//     }
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('No connected device')),
//     );
//   }

//   _rotating = false;
// }
@override
void initState() {
  super.initState();
  _selectedRotation = RotationStore.selectedRotation;
  // _turns = _rotToDeg(_selectedRotation) / 360.0;
  DisplayManager.initialize(widget.bluetooth);
}


  // static const List<Color> availableColors = [
  //   Colors.white,
  //   Colors.red,
  //   Colors.green,
  //   Colors.blue,
  //   Colors.yellow,
  //   Colors.orange,
  //   Colors.purple,
  //   Colors.cyan,
  //   Colors.pink,
  //   Colors.teal,
  //   Colors.amber,
  // ];

  Map<String, bool> expandedSections = {
    'brightness': false,
    'orientation': false,
  };

void toggleSection(String section) {
  setState(() {
    expandedSections.updateAll((key, value) => key == section ? !value : false);
  });
}


  Future<void> setBrightness(double value) async {
    setState(() => brightness = value);
    // بروزرسانی روشنایی کلی اپلیکیشن برای استفاده در DisplayManager
    ColorConfig.ledMasterBrightness = value;
    if (widget.isConnected) {
      // تنظیم روشنایی به‌صورت سه سطح برای دستگاه بلوتوثی
      final Brightness level = value < 0.33
          ? Brightness.minimum
          : (value < 0.66 ? Brightness.medium : Brightness.high);
      await widget.bluetooth.setBrightness(level);
    }
  }



  Future<void> resetToDefaults() async {
    setState(() {
      brightness = 0.5;
      _selectedRotation = ScreenRotation.degree0;
      selectedColor = Colors.white;
      expandedSections.updateAll((key, value) => false);
    });

    // Update global config so that future refreshes/games use the defaults
    DisplayManager.recordLastDisplay(
      path: 'assets/logopixply.png',
      type: DisplayType.image,
    );
    ColorConfig.ledMasterBrightness = 0.5;
    ColorConfig.setColor(Colors.white);
    RotationStore.setRotation(ScreenRotation.degree0);

    if (widget.isConnected) {
      await DisplayManager.refreshDisplay(clearBeforeSend: true);
    }
  }
  




 Future<void> pickDisplayColor() async {
  Color temp = ColorConfig.selectedDisplayColor;

  final Color? picked = await showDialog<Color>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return LayoutBuilder(
        builder: (ctx, constraints) {
          final maxW = math.min(constraints.maxWidth, 480.0);
          final maxH = math.min(constraints.maxHeight, 720.0); // cap height
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxW,
                maxHeight: maxH, // make dialog scrollable if content grows
              ),
              child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // پیکر سفارشی: فقط پیش‌نمایش محلی را برگردان
                      PixColorPickerPanel(
                        mode: ColorPickerMode.svAndHue,
                        onPreviewChanged: (c) => temp = c, // فقط لوکال
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('Cancel' , style: TextStyle( color: Colors.white , fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w400),),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                               style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(147, 255, 131, 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => Navigator.pop(ctx, temp),
                              child: const Text('Apply' , style: TextStyle( color: Color.fromARGB(255, 0, 0, 0) , fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w400),),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (picked != null) {
    // 1) اعمال سراسری رنگ
    ColorConfig.setColor(picked);
    setState(() => selectedColor = picked);

    // 2) آپدیت فوری صفحه‌نمایش (بدون نیاز به قطع/پلی مجدد)
    // await DisplayManager.refreshDisplay();
  }
}

// Widget _orientationControls() {
//   final deg = _rotToDeg(_selectedRotation);
//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 16),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         // +90 (چپ تصویر نمونه)
//         _rotButton(
//           label: '+ 90°',
//          icon: SvgPicture.asset('assets/arrow-rotate-left.svg', width: 17, height: 8), // یا SvgPicture.asset('assets/rot_cw.svg', width: 24, height: 24)
//           onTap: () => _applyRotation( 90),
//         ),

//         // پیش‌نمایش وسط با انیمیشن چرخش
//         _rotPreview(deg),

//         // -90 (راست تصویر نمونه)
//         _rotButton(
//           label: '- 90°',
//           // icon: Icon(Icons.rotate_left, color: Colors.white, size: 22), // یا SvgPicture.asset('assets/rot_ccw.svg', width: 24, height: 24)
//           icon: SvgPicture.asset('assets/arrow-rotate-right.svg', width: 17, height: 8),
//           onTap: () => _applyRotation(-90),
//         ),
//       ],
//     ),
//   );
// }

// Widget _rotButton({
//   required String label,
//   required Widget icon,
//   required VoidCallback onTap,
// }) {
//   return Material(
//     color: Colors.transparent,
//     child: InkWell(
//       onTap: onTap,
//       customBorder: const CircleBorder(),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             icon,
//             const SizedBox(height: 6),
//             Text(
//               label,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 fontFamily: 'Poppins',
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// Widget _rotPreview(int deg) {
//   return SizedBox(
//     width: 45, 
//     height: 45,
//     child: Stack(
//       alignment: Alignment.center,
//       clipBehavior: Clip.none, 
//       children: [
//         AnimatedRotation(
//           duration: const Duration(milliseconds: 220),
//           curve: Curves.easeInOut,
//           turns: -deg / 360.0, // degrees → turns
//           child: Container(
//             width: 36,
//             height: 36,
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.white, width: 2),
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//         ),

       
//         Positioned(
//           top: -8,   
//           left: 0,
//           child: SvgPicture.asset(
//             'assets/arrow-square-1.svg',
//             width: 17,
//             height: 8,
//             colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
//           ),
//         ),

        
//         Positioned(
//           bottom: -8, 
//           right: 0,
//           child: SvgPicture.asset(
//             'assets/arrow-square-2.svg',
//             width: 17,
//             height: 8,
//             colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
//           ),
//         ),
//       ],
//     ),
//   );
// }



  Widget _buildTile(String label, VoidCallback onTap, {String? iconPath, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(52.5),
        ),
        child: Row(
          children: [
            if (iconPath != null)
            SvgPicture.asset(
          iconPath,
          width: 36,
          height: 36,
          colorFilter: iconPath.contains('bluetooth')
          ? ColorFilter.mode(widget.isConnected ? Colors.green : Colors.white, BlendMode.srcIn)
          : null, 
),

            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
            const Spacer(),
            trailing ??
              (label == "Brightness" || label == "Orientation"
                  ? Icon(
                      expandedSections[label.toLowerCase()] == true
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 28,
                    )
                  : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
    Widget _buildExpandedSection(Widget child) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
margin: const EdgeInsets.only(top: 0, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(52.5),
      ),
      child: child,
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
     return  Column(
        children: [
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Colors.greenAccent,
            onChanged: onChanged,
          ),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: Stack(
      children: [
    SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Setting",
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
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
                        'assets/plus.svg',
                        width: 35,
                        height: 35,
                        colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),

            _buildTile("Brightness", () => toggleSection("brightness"), iconPath: 'assets/brightness.svg'),
            if (expandedSections['brightness']!)
               _buildExpandedSection(
              _buildSlider(
                value: brightness,
                min: 0,
                max: 1,
                divisions: 10,
                label: brightness < 0.33 ? "Low" : brightness < 0.66 ? "Medium" : "High",
                onChanged: setBrightness,
              ),
            ),
            _buildTile("Orientation", () => toggleSection("orientation"), iconPath: 'assets/rotate.svg'),
            if (expandedSections['orientation']!)
_buildExpandedSection(
  Column(
    children: [
      RadioListTile<ScreenRotation>(
        title: const Text('0° (Normal)', style: TextStyle(color: Colors.white)),
        value: ScreenRotation.degree0,
        groupValue: _selectedRotation,
onChanged: (value) async {
  if (value != null) {
    setState(() => _selectedRotation = value);
     RotationStore.setRotation(value);
     await widget.bluetooth.setRotation(value);
     await Future.delayed(Duration(milliseconds: 300)); 
    //  await DisplayManager.refreshDisplay(); 
  }
}

),


      RadioListTile<ScreenRotation>(
        title: const Text('90° (Right)', style: TextStyle(color: Colors.white)),
        value: ScreenRotation.degree90,
        groupValue: _selectedRotation,
onChanged: (value) async {
  if (value != null) {
    setState(() => _selectedRotation = value);
     RotationStore.setRotation(value);
     await widget.bluetooth.setRotation(value);
     await Future.delayed(Duration(milliseconds: 300));
    //  await DisplayManager.refreshDisplay(); 

  }
}

),
RadioListTile<ScreenRotation>(
  title: const Text('180° (Upside Down)', style: TextStyle(color: Colors.white)),
  value: ScreenRotation.degree180,
  groupValue: _selectedRotation,
onChanged: (value) async {
  if (value != null) {
    setState(() => _selectedRotation = value);
     RotationStore.setRotation(value);
     await widget.bluetooth.setRotation(value);
     await Future.delayed(Duration(milliseconds: 300)); 
    //  await DisplayManager.refreshDisplay(); 

  }
}

),

RadioListTile<ScreenRotation>(
  title: const Text('270° (Left)', style: TextStyle(color: Colors.white)),
  value: ScreenRotation.degree270,
  groupValue: _selectedRotation,
onChanged: (value) async {
  if (value != null) {
    setState(() => _selectedRotation = value);
     RotationStore.setRotation(value);
     await widget.bluetooth.setRotation(value);
     await Future.delayed(Duration(milliseconds: 300)); 
    //  await DisplayManager.refreshDisplay(); 

  }
}

),
    ],
  ),
),



                        _buildTile(
              "Display Color",
              pickDisplayColor,
              iconPath: 'assets/displaycolor.svg',
              
            ),

            _buildTile(
              "Reset to Default",
              resetToDefaults,
              iconPath: 'assets/reset.svg',

              
            ),

          ],
        ),
      ),
    Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 323,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(41),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem('assets/planet-saturn 1.svg', 0),
                _buildNavItem('assets/dices.svg', 1),
                _buildNavItem('assets/Heart 1.svg', 2),
                _buildNavItem('assets/Setting.svg', 3),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
),
    );
  }
  Widget _buildNavItem(String asset, int index) {
final bool isSelected = (index == 3);
    return GestureDetector(
      onTap: () {
      if (index == 0) {
         } else if (index == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GamesScreen(
      bluetooth: widget.bluetooth,
      isConnected: widget.isConnected,
            ),
          ),
        );
      }
           if (index == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscoverPage(
      bluetooth: widget.bluetooth,
      isConnected: widget.isConnected,
            ),
          ),
        );
      }
                 if (index == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LikesPage(
      bluetooth: widget.bluetooth,
      isConnected: widget.isConnected,
            ),
          ),
        );
      }

      },
      child: Container(
    width: 71,
    height: 71,
    decoration: BoxDecoration(
      color: isSelected ? Colors.white : const Color.fromRGBO(50, 50, 50, 1),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: SvgPicture.asset(
        asset,
        width: 36,
        height: 36,
        colorFilter: ColorFilter.mode(
          isSelected ? Colors.black : Colors.white,
          BlendMode.srcIn,
        ),
      ),
    ),
  ),
  );
}


}

// display color
enum ColorPickerMode { svAndHue, hueAndLightness }

class PixColorPickerPanel extends StatefulWidget {
  const PixColorPickerPanel({
    super.key,
    this.mode = ColorPickerMode.svAndHue,
    this.onPreviewChanged, // choose one
  });

  final ColorPickerMode mode;
  final ValueChanged<Color>? onPreviewChanged;

  @override
  State<PixColorPickerPanel> createState() => _PixColorPickerPanelState();
}

class _PixColorPickerPanelState extends State<PixColorPickerPanel> {
  static const double _minV = 0.08; // avoid pure black

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final c = ColorConfig.selectedDisplayColor;
    final h = HSVColor.fromColor(c);
    // Force V=1.0 on open (max brightness)
    _hsv = HSVColor.fromAHSV(1.0, h.hue, h.saturation, 1.0);
  }

  HSVColor _normalize(HSVColor hsv) {
    final v = hsv.value < _minV ? _minV : hsv.value;
    return HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, v);
  }

  void _commit(HSVColor next) {
    final fixed = _normalize(next);
    setState(() => _hsv = fixed);
    widget.onPreviewChanged?.call(fixed.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final colorNow = _hsv.toColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // preview chip (left), like your screenshots
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: colorNow,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (widget.mode == ColorPickerMode.svAndHue) ...[
            // SV square
            AspectRatio(
              aspectRatio: 1,
              child: _SVSquare(
                hue: _hsv.hue,
                saturation: _hsv.saturation,
                value: _hsv.value,
                onChanged: (s, v) => _commit(HSVColor.fromAHSV(1.0, _hsv.hue, s, v)),
              ),
            ),
            const SizedBox(height: 14),
            // Hue bar
           HueBar(
  hue: _hsv.hue,
  onChanged: (h) => _commit(HSVColor.fromAHSV(1.0, h, _hsv.saturation, _hsv.value)),
  height: 28,            // همان نسبت عکس
  trackThickness: 14,    // ضخامت نوار داخلی
  thumbRadius: 10,       // دایره سفید کوچک
),

          ] else ...[
            // Lightness bar (white -> hue color)
            _LightnessBar(
              hue: _hsv.hue,
              saturation: _hsv.saturation,
              value: _hsv.value,
              onChanged: (v) => _commit(HSVColor.fromAHSV(1.0, _hsv.hue, _hsv.saturation, v)),
            ),
            const SizedBox(height: 14),
            // Hue bar
           HueBar(
  hue: _hsv.hue,
  onChanged: (h) => _commit(HSVColor.fromAHSV(1.0, h, _hsv.saturation, _hsv.value)),
  height: 28,            // همان نسبت عکس
  trackThickness: 14,    // ضخامت نوار داخلی
  thumbRadius: 20,       // دایره سفید کوچک
),

          ],
        ],
      ),
    );
  }
}

/* ====================== SV Square ====================== */
class _SVSquare extends StatefulWidget {
  const _SVSquare({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double s, double v) onChanged;

  @override
  State<_SVSquare> createState() => _SVSquareState();
}

class _SVSquareState extends State<_SVSquare> {
  Offset _thumb = const Offset(1, 0); // top-right

  @override
  void initState() {
    super.initState();
    _thumb = Offset(
      widget.saturation.clamp(0, 1),
      (1.0 - widget.value).clamp(0, 1),
    );
  }

  void _update(Offset local, double side, double edge) {
    final track = side - edge * 2;
    // map local -> [0..1] inside the inner track
    double nx = ((local.dx - edge) / track).clamp(0.0, 1.0);
    double ny = ((local.dy - edge) / track).clamp(0.0, 1.0);

    _thumb = Offset(nx, ny);
    final s = nx;
    final v = 1.0 - ny;
    widget.onChanged(s, v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1.0, widget.hue, 1.0, 1.0).toColor();

    return LayoutBuilder(
      builder: (context, cons) {
        final side = math.min(cons.maxWidth, 360.0);
        const edge = 10.0; // inner safety edge for thumb & painting
        final track = side - edge * 2;

        return Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: side,
              height: side,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanDown: (d) => _update(d.localPosition, side, edge),
                    onPanUpdate: (d) => _update(d.localPosition, side, edge),
                    child: Stack(
                      children: [
                        // paint inside safe edge to avoid corner artifacts
                        Padding(
                          padding: const EdgeInsets.all(edge),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, hueColor],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // thumb centered within track, with clamp
                        Positioned(
                          left: edge + (_thumb.dx * track) - 10,
                          top:  edge + (_thumb.dy * track) - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: Colors.transparent,
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}



/* ====================== Hue Bar ====================== */
class HueBar extends StatefulWidget {
  const HueBar({
    super.key,
    required this.hue,                 // 0..360
    required this.onChanged,
    this.height = 28,                  // outer capsule height
    this.trackThickness = 14,          // inner gradient band height
    this.thumbRadius = 10,             // thumb radius
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final double hue;
  final ValueChanged<double> onChanged;
  final double height;
  final double trackThickness;
  final double thumbRadius;
  final EdgeInsets padding;

  @override
  State<HueBar> createState() => _HueBarState();
}

class _HueBarState extends State<HueBar> {
  late double _h; // 0..360

  @override
  void initState() {
    super.initState();
    _h = widget.hue.clamp(0, 360);
  }

  @override
  void didUpdateWidget(covariant HueBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hue != widget.hue) {
      _h = widget.hue.clamp(0, 360);
    }
  }

  void _update(Offset local, double width) {
    final usable = width - widget.padding.horizontal;
    final x = (local.dx - widget.padding.left).clamp(0.0, usable);
    final h = (x / usable) * 360.0;
    setState(() => _h = h);
    widget.onChanged(h);
  }

  @override
Widget build(BuildContext context) {
  final r = math.min(14.0, widget.height / 2);
  return SizedBox(
    height: widget.height,
    child: LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final usable = w - widget.padding.horizontal;

      // thumb center on the inner band
      final centerX = (_h / 360.0) * usable + widget.padding.left;
      final centerY = widget.padding.top + (widget.trackThickness / 2);

      // clamp left so the circle stays inside
      final left = (centerX - widget.thumbRadius)
          .clamp(0.0, w - 2 * widget.thumbRadius);

      const nudge = -0.5; // sub-pixel adjustment for crisp centering

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _update(d.localPosition, w),
        onPanUpdate: (d) => _update(d.localPosition, w),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(r),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
          ),
          padding: widget.padding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.trackThickness / 2),
                  child: SizedBox(
                    height: widget.trackThickness,
                    width: double.infinity,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF0000), Color(0xFFFFFF00),
                            Color(0xFF00FF00), Color(0xFF00FFFF),
                            Color(0xFF0000FF), Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                          stops: [0.0, 1/6, 2/6, 3/6, 4/6, 5/6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: centerY - widget.thumbRadius + nudge,
                child: Container(
                  width: widget.thumbRadius * 2,
                  height: widget.thumbRadius * 2,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1.0, _h, 1.0, 1.0).toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

}



/* ====================== Lightness Bar ====================== */
class _LightnessBar extends StatefulWidget {
  const _LightnessBar({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_LightnessBar> createState() => _LightnessBarState();
}

class _LightnessBarState extends State<_LightnessBar> {
  double _v = 1.0;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  void _update(Offset local, Size size) {
    double x = (local.dx / size.width).clamp(0.0, 1.0);
    final v = x; // left = white-ish, right = full color
    _v = v;
    widget.onChanged(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final full = HSVColor.fromAHSV(1.0, widget.hue, widget.saturation, 1.0).toColor();

    return SizedBox(
      height: 28,
      child: LayoutBuilder(builder: (context, cons) {
        final w = cons.maxWidth;
        final x = _v * w;

        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, Size(w, 20)),
          onPanUpdate: (d) => _update(d.localPosition, Size(w, 20)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Stack(
              children: [
                // white -> full color gradient
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, full],
                        ),
                      ),
                    ),
                  ),
                ),
                // thumb
                Positioned(
                  left: math.max(0, math.min(w - 0, x)) - 10,
                  top: 1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1.0, widget.hue, widget.saturation, _v).toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
