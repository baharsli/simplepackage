import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pixply/Settings/color_config.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:pixply/Settings/playback_state.dart';
import 'package:pixply/Settings/rotation_config.dart';
import 'package:image/image.dart' as img;
import 'package:pixply/explore/yourgame.dart';
import 'package:provider/provider.dart';
import 'game_creation_store.dart';
import 'game_data.dart';
import 'package:video_player/video_player.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:led_ble_lib/led_ble_lib.dart';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:pixply/explore/design_game_page.dart';
// import 'package:country_picker/country_picker.dart';




late LedBluetooth _bluetooth;
bool _isConnected = false;
int ledWidth = 56;
int ledHeight = 56;
class GamePreviewPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;
  final bool alreadyOnBoard;
  
  const GamePreviewPage({
    super.key,
    required this.bluetooth,
    required this.isConnected,
    this.alreadyOnBoard = false,
  });
  @override
  State<GamePreviewPage> createState() => _GamePreviewPageState();
}

class _GamePreviewPageState extends State<GamePreviewPage> {
  GameData? _data;
  bool isHovered = false;
  bool isPressed = false;
  bool _isLoading = false;
  Color selectedColor = Colors.white;
  String lastImagePath = 'assets/logopixply.png';

@override
void initState() {
  super.initState();
      _bluetooth = widget.bluetooth;
    _isConnected = widget.isConnected;
    DisplayManager.initialize(_bluetooth);
    _initBluetooth();
    _prepareBoardForGame();
    ColorConfig.addListener(_onColorChanged);
  Future.microtask(() {
    // ignore: use_build_context_synchronously
    final args = ModalRoute.of(context )?.settings.arguments;
    if (args is String) {
      final m = Hive.box<Map>('my_creations').get(args);
      if (m != null) {
        setState(() => _data = GameData.fromJson(Map<String,dynamic>.from(m)));
      }
    } else {
      // ignore: use_build_context_synchronously
      _data = context.read<GameCreationStore>().current();
      setState(() {});
    }
  });

}
  @override
  void dispose() {
    ColorConfig.removeListener(_onColorChanged);
    super.dispose();
  }

  // edite page //
  void _openEditInfoSheet(GameData data) async {
  // Controllers pre-filled with current values
  final nameCtrl        = TextEditingController(text: data.name);
  final gameplayCtrl = TextEditingController(text: data.gameplayDescription);
final mediaUrlCtrl = TextEditingController(text: data.instructionVideoUrl.trim());
final localPathCtrl = TextEditingController(text: (data.localMediaPath ?? '').trim());

  // final overviewCtrl    = TextEditingController(text: data.overview);
  // final aboutCtrl       = TextEditingController(text: data.about);
  // final playersFromCtrl = TextEditingController(text: data.playersFrom?.toString() ?? '');
  // final playersToCtrl   = TextEditingController(text: data.playersTo?.toString() ?? '');
  // final ageMinCtrl      = TextEditingController(text: data.ageMin?.toString() ?? '');
  // final ageMaxCtrl      = TextEditingController(text: data.ageMax?.toString() ?? '');

  // String? selectedCountry = (data.region?.trim().isEmpty ?? true) ? null : data.region!.trim();

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1F1F1F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
    ),
    builder: (ctx) {
      // Helpers
      InputDecoration deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60, fontFamily: 'Poppins'),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      );

      Widget label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
          style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins',
          ),
        ),
      );

      // Widget numberPair({
      //   required String title,
      //   required TextEditingController fromCtrl,
      //   required TextEditingController toCtrl,
      //   String fromHint = 'From',
      //   String toHint = 'To',
      // }) {
      //   return Column(
      //     crossAxisAlignment: CrossAxisAlignment.start,
      //     children: [
      //       label(title),
      //       Row(
      //         children: [
      //           Expanded(
      //             child: TextField(
      //               controller: fromCtrl,
      //               keyboardType: TextInputType.number,
      //               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      //               style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      //               decoration: deco(fromHint),
      //             ),
      //           ),
      //           const SizedBox(width: 12),
      //           Expanded(
      //             child: TextField(
      //               controller: toCtrl,
      //               keyboardType: TextInputType.number,
      //               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      //               style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      //               decoration: deco(toHint),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ],
      //   );
      // }

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 16, left: 16, right: 16,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 56, height: 6,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white12, borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                const Text(
                  'Edit Game Info',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 18),

                // Name
                label('Name'),
                TextField(
                  controller: nameCtrl,
                  maxLength: 20, // matches Info.titleMaxLength
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: deco('Game name'),
                ),
                const SizedBox(height: 16),
                // --- Game Play Description ---
label('Game Play Description'),
TextField(
  controller: gameplayCtrl,
  maxLines: 4,
  maxLength: 500,
  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
  decoration: deco('Describe how to play...'),
),
const SizedBox(height: 16),

// --- Media URL ---
label('Media URL (image/video)'),
TextField(
  controller: mediaUrlCtrl,
  maxLines: 1,
  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
  decoration: deco('https://... (image or video URL)'),
),
const SizedBox(height: 12),

// --- Local Media ---
label('Local Media (pick from device)'),
Row(
  children: [
    Expanded(
      child: TextField(
        controller: localPathCtrl,
        readOnly: true,
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        decoration: deco('Pick a local file (image/video)'),
      ),
    ),
    const SizedBox(width: 8),
    SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () async {
          try {
            final res = await FilePicker.platform.pickFiles(
              type: FileType.media,
              allowMultiple: false,
            );
            if (res != null && res.files.single.path != null) {
              localPathCtrl.text = res.files.single.path!;
              // اگر فایل لوکال انتخاب شد، می‌تونی URL رو خالی کنی (اختیاری):
              // mediaUrlCtrl.text = '';
              (ctx as Element).markNeedsBuild();
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File pick error: $e')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF444444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: const Text('Choose', style: TextStyle(color: Colors.white)),
      ),
    ),
  ],
),

// --- Edit LED Board Design (go to canvas) ---

const SizedBox(height: 16),


                // Overview
                // label('Overview'),
                // TextField(
                //   controller: overviewCtrl,
                //   maxLines: 4,
                //   maxLength: 300, // matches Info.overviewMaxLength
                //   style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                //   decoration: deco('Short overview (how to play / what it is)'),
                // ),
                // const SizedBox(height: 16),

                // // About
                // label('About'),
                // TextField(
                //   controller: aboutCtrl,
                //   maxLines: 3,
                //   style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                //   decoration: deco('About the game (origin, flavor text, etc.)'),
                // ),
                // const SizedBox(height: 16),

                // // Players
                // numberPair(
                //   title: 'Players',
                //   fromCtrl: playersFromCtrl,
                //   toCtrl: playersToCtrl,
                // ),
                // const SizedBox(height: 16),

                // // Age
                // numberPair(
                //   title: 'Age',
                //   fromCtrl: ageMinCtrl,
                //   toCtrl: ageMaxCtrl,
                //   fromHint: 'Min',
                //   toHint: 'Max',
                // ),
                // const SizedBox(height: 16),

                // // Region
                // label('Region / Country'),
                // GestureDetector(
                //   onTap: () {
                //     showCountryPicker(
                //       context: ctx,
                //       showPhoneCode: false,
                //       countryListTheme: CountryListThemeData(
                //         backgroundColor: const Color(0xFF1F1F1F),
                //         inputDecoration: deco('Search...'),
                //         textStyle: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                //       ),
                //       onSelect: (c) {
                //         selectedCountry = c.name;
                //         // rebuild the sheet to show new selection
                //         (ctx as Element).markNeedsBuild();
                //       },
                //     );
                //   },
                //   child: Container(
                //     height: 52,
                //     decoration: BoxDecoration(
                //       color: const Color(0xFF2A2A2A),
                //       borderRadius: BorderRadius.circular(24),
                //     ),
                //     padding: const EdgeInsets.symmetric(horizontal: 16),
                //     alignment: Alignment.centerLeft,
                //     child: Text(
                //       selectedCountry ?? 'Select country / region',
                //       style: TextStyle(
                //         color: selectedCountry == null ? Colors.white60 : Colors.white,
                //         fontFamily: 'Poppins',
                //       ),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 24),

                // Actions
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(41)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      // // Basic validation
                      // int? pFrom = playersFromCtrl.text.isEmpty ? null : int.tryParse(playersFromCtrl.text);
                      // int? pTo   = playersToCtrl.text.isEmpty   ? null : int.tryParse(playersToCtrl.text);
                      // int? aMin  = ageMinCtrl.text.isEmpty      ? null : int.tryParse(ageMinCtrl.text);
                      // int? aMax  = ageMaxCtrl.text.isEmpty      ? null : int.tryParse(ageMaxCtrl.text);

                      // String err = '';
                      // if (nameCtrl.text.trim().isEmpty) {
                      //   err = 'Name cannot be empty';
                      // } else if (pFrom != null && pTo != null && pFrom > pTo) {
                      //   err = 'Players: From cannot be greater than To';
                      // } else if (aMin != null && aMax != null && aMin > aMax) {
                      //   err = 'Age: Min cannot be greater than Max';
                      // }

                      // if (err.isNotEmpty) {
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     SnackBar(content: Text(err)),
                      //   );
                      //   return;
                      // }

                      Navigator.of(ctx).pop(<String, dynamic>{
                        'name'       : nameCtrl.text.trim(),
                          'gameplayDescription' : gameplayCtrl.text.trim(),
  'instructionVideoUrl' : mediaUrlCtrl.text.trim(),
  'localMediaPath'      : localPathCtrl.text.trim(),
                        // 'overview'   : overviewCtrl.text.trim(),
                        // 'about'      : aboutCtrl.text.trim(),
                        // 'playersFrom': pFrom,
                        // 'playersTo'  : pTo,
                        // 'ageMin'     : aMin,
                        // 'ageMax'     : aMax,
                        // 'region'     : selectedCountry,
                      });
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!mounted) return;

 if (result != null) {
  final store = context.read<GameCreationStore>();
  final cur = store.current(); // مقدار فعلی برای پر کردن فیلدهای غیرفعال

  // 1) Info: فقط name را از result می‌گیریم؛ بقیه از مقدار فعلی
  final updatedName = (result['name'] as String? ?? cur.name).trim();

  store.setInfo(
    name:        updatedName,
    about:       cur.about,                // چون UI فعلاً کامنت است، مقدار فعلی را نگه می‌داریم
    overview:    cur.overview,
    playersFrom: cur.playersFrom,
    playersTo:   cur.playersTo,
    ageMin:      cur.ageMin,
    ageMax:      cur.ageMax,
    region:      cur.region,
  );

  // 2) Instructions: gameplay + media
  final gameplay = (result['gameplayDescription'] as String? ?? cur.gameplayDescription).trim();
  final url      = (result['instructionVideoUrl'] as String? ?? cur.instructionVideoUrl).trim();
  final local    = (result['localMediaPath'] as String? ?? (cur.localMediaPath ?? '')).trim();
  store.setInstruction(
    gameplayDescription: gameplay,
    videoUrl: url,
    localMediaPath: local.isEmpty ? null : local,
  );

  // 3) Refresh UI
  setState(() {
    _data = store.current();
  });

  // 4) Persist to Hive (اگر از saved creation آمده‌ای)
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is String) {
    try {
      final box = Hive.box<Map>('my_creations');
      final currentJson = store.current().toJson();
      await box.put(args, currentJson);
    } catch (_) {}
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Game info updated')),
  );
}

}


  img.Image _rebuildCanvasFromGameData({
  required int grid,
  required List<int> pixelsArgb,
}) {
  // از آرایه‌ی ARGB یک تصویر img.Image می‌سازیم
  final canvas = img.Image(width: grid, height: grid);
  for (int y = 0; y < grid; y++) {
    for (int x = 0; x < grid; x++) {
      final idx = y * grid + x;
      final argb = pixelsArgb[idx];
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8)  & 0xFF;
      final b = (argb)       & 0xFF;
      canvas.setPixelRgb(x, y, r, g, b);
    }
  }
  return canvas;
}

Uint8List _imageToRawRGB(img.Image src) {
  final w = src.width, h = src.height;
  final out = List<int>.filled(w * h * 3, 0, growable: false);
  int k = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = src.getPixel(x, y); // RGBA
      out[k++] = p.r.toInt(); // R
      out[k++] = p.g.toInt(); // G
      out[k++] = p.b.toInt(); // B
    }
  }
  return Uint8List.fromList(out);
}
// send data to board
// Future<void> _sendSavedDesignToBoard(GameData data) async {
//   final grid = data.gridSize;
//   final pixels = data.pixelsArgb;

//   if (!_isConnected) {
//     _showMessage('Please connect to a device first');
//     return;
//   }
//   if (grid == null || pixels == null || pixels.isEmpty) {
//     _showMessage('No saved design data');
//     return;
//   }

//   try {
//     // بازسازی تصویر از داده‌های ذخیره‌شده
//     img.Image canvas = _rebuildCanvasFromGameData(grid: grid, pixelsArgb: pixels);

//     // تغییر اندازه تصویر
//     canvas = img.copyResize(canvas, width: ledWidth, height: ledHeight);

   

//     final rawRgb = _imageToRawRGB(canvas); // دقیقا RGB مثل صفحه دیزاین

//     final program = Program.bmp(
//       partitionX: 0,
//       partitionY: 0,
//       partitionWidth: ledWidth,  
//       partitionHeight: ledHeight,  
//       bmpData: rawRgb,
//       specialEffect: SpecialEffect.fixed,
//       speed: 0,
//       stayTime: 30,
//       circularBorder: 0,
//       brightness: 100,
//     );

//  if (_bluetooth.isConnected) {
//       await _bluetooth.deleteAllPrograms();
//       await _bluetooth.setRotation(RotationStore.selectedRotation);
//       final ok = await _bluetooth.sendTemporaryProgram(program, circularBorder: 0);
//       _showMessage(ok ? 'Design sent to LED board' : 'Failed to send design');
//     } else {
//       _showMessage('Not connected to LED board');
//     }
//   } catch (e) {
//     _showMessage('Error: $e');
//   }
// }


  void _onColorChanged(Color newColor) {
    if (mounted) {
      _refreshImageWithNewColor();
    }
  }

  // clear board
  Future<void> _prepareBoardForGame() async {
    if (_bluetooth.isConnected) {
      await _bluetooth.updatePlaylistComplete();
      debugPrint("✅ Board cleared when entering Adugo page");
    }
  }

  // Bluetooth initialization
  Future<void> _initBluetooth() async {
    _isConnected = widget.isConnected;
    if (!_bluetooth.isConnected) {
      await _bluetooth.initialize();
    }
    _bluetooth.onConnectionStateChanged.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
  }

  // Load and process BMP image
  Future<Uint8List> loadColoredBmp(String path) async {
    ByteData data = await rootBundle.load(path);
    final img.Image? original = img.decodeImage(data.buffer.asUint8List());
    if (original == null) throw Exception('Image decode failed');

    final img.Image resized =
        img.copyResize(original, width: ledWidth, height: ledHeight);
    final rotation = RotationStore.selectedRotation;
    img.Image rotated = resized;

    switch (rotation) {
      case ScreenRotation.degree90:
        rotated = img.copyRotate(resized, angle: 90);
        break;
      case ScreenRotation.degree180:
        rotated = img.copyRotate(resized, angle: 180);
        break;
      case ScreenRotation.degree270:
        rotated = img.copyRotate(resized, angle: 270);
        break;
      case ScreenRotation.degree0:
        break;
    }
    final List<int> buffer = [];
    final selectedColor = ColorConfig.selectedDisplayColor;

    for (int y = 0; y < rotated.height; y++) {
      for (int x = 0; x < rotated.width; x++) {
        final pixel = rotated.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance > 128) {
          buffer.add(selectedColor.red);
          buffer.add(selectedColor.green);
          buffer.add(selectedColor.blue);
        } else {
          buffer.add(0);
          buffer.add(0);
          buffer.add(0);
        }
      }
    }
    return Uint8List.fromList(buffer);
  }

  Future<Uint8List> loadImageData(img.Image originalImage) async {
    // Resize to match LED screen
    final img.Image resizedImage =
        img.copyResize(originalImage, width: ledWidth, height: ledWidth);
    return image2bgr(resizedImage);
  }

  Uint8List image2bgr(img.Image resizedImage) {
    List<int> ledData = [];
    // Convert color channel order from RGB to BGR
    for (int y = 0; y < ledWidth; y++) {
      for (int x = 0; x < ledWidth; x++) {
        // Get pixel value (RGBA format)
        final pixel = resizedImage.getPixel(x, y);

        // Extract RGB channel values
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        ledData.add(r); // R component
        ledData.add(g); // G component
        ledData.add(b); // B component
      }
    }
    return Uint8List.fromList(ledData);
  }
  Future<void> _playSavedDesignToBoard(GameData data) async {
  final grid = data.gridSize;
  final pixels = data.pixelsArgb;

  if (!_bluetooth.isConnected) {
    _showMessage('Please connect to a device first');
    return;
  }
  if (grid == null || pixels == null || pixels.isEmpty) {
    _showMessage('No saved design data');
    return;
  }

  try {
    // 1) بازسازی تصویر از استور
    img.Image canvas = _rebuildCanvasFromGameData(grid: grid, pixelsArgb: pixels);

    // 2) Resize به اندازه‌ی برد
    canvas = img.copyResize(canvas, width: ledWidth, height: ledHeight);

    // 3) تبدیل به BGR (سازگار با بورد)
    final rawRgb = _imageToRawRGB(canvas);

    // 4) آماده‌سازی نمایشگر (همیشه قبل از پخش نهایی)
    await _bluetooth.switchLedScreen(true);
    await _bluetooth.setBrightness(Brightness.high);
    await _bluetooth.setRotation(RotationStore.selectedRotation);

    // 5) پاک‌سازی امن پلی‌لیست (حذف → افزودن → آپدیت)
    await _bluetooth.updatePlaylistComplete();
    await _bluetooth.deleteAllPrograms();
    await _bluetooth.updatePlaylistComplete();

    // 6) ساخت Program نهایی
    final program = Program.bmp(
      partitionX: 0,
      partitionY: 0,
      partitionWidth: ledWidth,
      partitionHeight: ledHeight,
      bmpData: rawRgb,
      specialEffect: SpecialEffect.fixed,
      speed: 50,
      stayTime: 300000, // شبیه _sendImageProgram
      circularBorder: 0,
      brightness: 100,
    );

    // 7) افزودن به پلی‌لیست و نهایی‌سازی
    await _bluetooth.addProgramToPlaylist(
      program,
      programCount: 1,
      programNumber: 0,
      playbackCount: 1,
      circularBorder: 0,
    );

    var ok = await _bluetooth.updatePlaylistComplete();
    if (!ok) {
      await Future.delayed(const Duration(seconds: 1));
      ok = await _bluetooth.updatePlaylistComplete();
    }

    _showMessage(ok ? 'Design is now playing on the board' : 'Failed to play design');
  } catch (e) {
    _showMessage('Error: $e');
  }
}

  Future<void> _sendImageProgram(String path) async {
    if (!_isConnected) {
      _showMessage('Please connect to a device first');
      return;
    }

    try {
      lastImagePath = path;
      await _bluetooth.switchLedScreen(true);
      await _bluetooth.setBrightness(Brightness.high);
      await _bluetooth.deleteAllPrograms();
      await _bluetooth.updatePlaylistComplete();
      await _bluetooth.setRotation(RotationStore.selectedRotation);
      await Future.delayed(Duration(milliseconds: 500));
      final bmp = await loadColoredBmp(path);

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
      // final success = await _bluetooth.sendTemporaryProgram(program, circularBorder: 0);

      // Add program to playlist
      await _bluetooth.addProgramToPlaylist(
        program,
        programCount: 1,
        programNumber: 0,
        playbackCount: 1,
        circularBorder: 0,
      );

      // Update playlist
      final success = await _bluetooth.updatePlaylistComplete();
      if (!success) {
        await Future.delayed(const Duration(seconds: 1));
        await _bluetooth.updatePlaylistComplete();
      }
      DisplayManager.recordLastDisplay(
        path: path,
        type: DisplayType.image,
      );
      _showMessage('Image playlist sent');
    } catch (e) {
      _showMessage('Error sending image: \$e');
    }
  }
    Future<void> _refreshImageWithNewColor() async {
    if (!_bluetooth.isConnected) {
      _showMessage("Device not connected");
      return;
    }

    try {
      // await _bluetooth.deleteAllPrograms();
      // await _bluetooth.updatePlaylistComplete();
      await _bluetooth.setRotation(RotationStore.selectedRotation);
      await Future.delayed(const Duration(milliseconds: 300)); // wait a bit
      await _sendImageProgram(lastImagePath);

      DisplayManager.recordLastDisplay(
          path: lastImagePath, type: DisplayType.image);
    } catch (e) {
      _showMessage("Error refreshing image: $e");
    }
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? context.watch<GameCreationStore>().data;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(49, 49, 49, 1),
      body: Stack(
         children: [
          SingleChildScrollView(
            child: Column(
            children: [
              // --- Header ---
              Padding(

                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                        width: 71,
                        height: 71,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                        child: IconButton(
                          icon: SvgPicture.asset('assets/close.svg',
                              width: 36, height: 36),
                          onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                          builder: (context) => Yourgame( bluetooth: widget.bluetooth,  isConnected: widget.isConnected),
                          ),
                          ),
                        ),
                      ),
                    
                    Text(
                      data.name.isEmpty ? 'Untitled Game' : data.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Container(
                        width: 71,
                        height: 71,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                          child: IconButton(
                          onPressed: () => _openEditInfoSheet(data),
                          icon: SvgPicture.asset(
                                'assets/edit.svg',
                               width: 33,
                            height: 33,
                          ),
                        ),
                      ),
                    
                  ],
                ),
              ), 
              const SizedBox(height: 30),

              // --- Media (Video/Local/Image/Design fallback) ---
              _MediaBox(data: data),

              const SizedBox(height: 50),

                            // --- Chips: Age / Players / Region ---
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   alignment: WrapAlignment.center, 
//                   runAlignment: WrapAlignment.center, 
//               children: [
//       if (data.ageMin != null || data.playersFrom != null || data.playersTo != null)
//         _chipInfo(
//           ageMin: data.ageMin,
//           playersFrom: data.playersFrom,
//           playersTo: data.playersTo,
//         ),
//         const SizedBox(width: 20),
//                     if (data.region != null && data.region!.trim().isNotEmpty)
//                     _chipTextOnly(data.region!),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 50),
//               // --- About / Overview ---
//               if (data.about.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       const Text(
//                         'Game Overview',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontWeight: FontWeight.w600,
//                           fontFamily: 'Poppins',
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         data.about,
//                         style: const TextStyle(
//                           color: Colors.white70,
//                           fontSize: 14,
//                           fontFamily: 'Poppins',
//                           fontWeight: FontWeight.w500,
//                         ),
//                         textAlign: TextAlign.center,
//  ),
//                     ],
//                   ),
//                 ),
                              const SizedBox(height: 50),

              // --- How to Play ---
              if (data.gameplayDescription.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Game Play Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.gameplayDescription,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w500,),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              // if (data.overview.isNotEmpty) ...[
              //   const SizedBox(height: 12),
              //   Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 20),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.center,
              //       children: [
              //         const Text(
              //           'Overview',
              //           style: TextStyle(
              //             color: Colors.white,
              //             fontSize: 20,
              //             fontWeight: FontWeight.w600,
              //             fontFamily: 'Poppins',
              //           ),
              //          textAlign: TextAlign.center, 
              //         ),
              //         const SizedBox(height: 8),
              //         Text(
              //           data.overview,
              //           style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w500,),
              //           textAlign: TextAlign.center,
              //         ),
              //       ],
              //     ),
              //   ),
              // ],
              const SizedBox(height: 100),
            ],
          ),
        ),
            Positioned(
            bottom: 20,
            left: 80,
            right: 80,
            child: PlayNowButton(
              isLoading: _isLoading,
              initialCompleted: widget.alreadyOnBoard,
              onComplete: () async {
                setState(() => _isLoading = true);
                try {
                  await Future.delayed(Duration(milliseconds: 100));
                  await _bluetooth.updatePlaylistComplete();
                  await _playSavedDesignToBoard(data);
                  await Future.delayed(
                      Duration(seconds: 10)); // simulate loading duration
                } catch (e) {
                  _showMessage('Error: $e');
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              onReset: () async {
                setState(() => _isLoading = true);
                try {
                  await Future.delayed(Duration(milliseconds: 100));
                  await _bluetooth.deleteAllPrograms(); // Clear display immediately
                  await _bluetooth.updatePlaylistComplete();
                  // Immediately send the next image
                  await _sendImageProgram(lastImagePath);
                  await Future.delayed(Duration(seconds: 10));
                  _showMessage('Image cleared from LED board.');
                } catch (e) {
                  _showMessage('Error: \$e');
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ),
          ],
        
),
      
    );
  }

// Widget _chipInfo({int? ageMin, int? playersFrom, int? playersTo}) {
//   final hasAge = ageMin != null;
//   final hasPlayers = (playersFrom != null || playersTo != null);

//   final playersText = "${playersFrom ?? '?'}-${playersTo ?? '?'}";

//   return Container(
//     width: 161,
//     height: 39,
//     decoration: BoxDecoration(
//       border: Border.all(color: Colors.grey),
//       borderRadius: BorderRadius.circular(19.5),
//     ),
//     padding: const EdgeInsets.symmetric(horizontal: 12), // فاصله یکنواخت از چپ و راست
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         if (hasAge) ...[
//           SvgPicture.asset(
//             'assets/age.svg',
//             width: 17,
//             height: 17,
//             colorFilter: const ColorFilter.mode(
//                 Color.fromARGB(255, 255, 255, 255), BlendMode.srcIn),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             "$ageMin+",
//             style: const TextStyle(
//                 color: Color.fromARGB(255, 255, 255, 255), fontSize: 12),
//           ),
//         ],

//         if (hasAge && hasPlayers) const SizedBox(width: 16), // فاصله ثابت و منطقی

//         if (hasPlayers) ...[
//           SvgPicture.asset(
//             'assets/Player.svg',
//             width: 17,
//             height: 17,
//             colorFilter: const ColorFilter.mode(
//                 Color.fromARGB(255, 255, 255, 255), BlendMode.srcIn),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             playersText,
//             style: const TextStyle(color: Colors.white70, fontSize: 12),
//           ),
//         ],
//       ],
//     ),
//   );
// }


// Widget _chipTextOnly(String text) {
//   return Container(
//                       width: 130,
//                       height: 39,
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey),
//                         borderRadius: BorderRadius.circular(19.5),
//     ),
//     child: Text(
//       text,
//       style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 14),
//       textAlign: TextAlign.center,
//     ),
//   );
// }
}


class _MediaBox extends StatefulWidget {
  final GameData data;
  const _MediaBox({required this.data});

  @override
  State<_MediaBox> createState() => _MediaBoxState();
}

class _MediaBoxState extends State<_MediaBox> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _MediaBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.instructionVideoUrl != widget.data.instructionVideoUrl ||
        oldWidget.data.localMediaPath != widget.data.localMediaPath) {
      _disposeController();
      _setupController();
    }
  }

  bool _isVideoPath(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv'].contains(ext);
  }

  bool _isImagePath(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.wbmp', '.svg'].contains(ext);
  }

  void _setupController() {
    final local = widget.data.localMediaPath?.trim();
    final url = widget.data.instructionVideoUrl.trim();

    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      if (_isVideoPath(local)) {
        _controller = VideoPlayerController.file(File(local));
      } else {
        _controller = null;
      }
    } else if (url.isNotEmpty) {
      if (_isVideoPath(url)) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _controller = null;
      }
    } else {
      _controller = null;
    }

    if (_controller != null) {
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller!
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      });
    }
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed height 208 with 20px horizontal padding
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 208,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: const Color(0xFF141414),
            child: _buildMediaCover(),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCover() {
    final local = widget.data.localMediaPath?.trim();
    final url = widget.data.instructionVideoUrl.trim();

    // Video (local or remote): fill container using FittedBox + BoxFit.cover
    if (_controller != null && _initialized) {
      final size = _controller!.value.size;
      final w = (size.width == 0) ? 1.0 : size.width;
      final h = (size.height == 0) ? 1.0 : size.height;

      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: w,
          height: h,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    // Local image
    if (local != null && local.isNotEmpty && File(local).existsSync() && _isImagePath(local)) {
      final isSvg = p.extension(local).toLowerCase() == '.svg';
      return isSvg
          ? SvgPicture.file(File(local), fit: BoxFit.cover)
          : Image.file(
              File(local),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (c, e, s) => _fallback(),
            );
    }

    // Remote image
    if (url.isNotEmpty && _isImagePath(url)) {
      final isSvg = p.extension(url).toLowerCase() == '.svg';
      return isSvg
          ? SvgPicture.network(url, fit: BoxFit.cover)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (c, e, s) => _fallback(),
            );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.perm_media_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 8),
          Text('No media', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

// class _PixelsPainter extends CustomPainter {
//   final int grid;
//   final List<int> pixels;
//   _PixelsPainter(this.grid, this.pixels);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final double cellW = size.width / grid;
//     final double cellH = size.height / grid;

//     final paint = Paint()..style = PaintingStyle.fill;

//     for (int y = 0; y < grid; y++) {
//       for (int x = 0; x < grid; x++) {
//         final idx = y * grid + x;
//         if (idx >= pixels.length) continue;
//         final argb = pixels[y * grid + x];
//         final a = (argb >> 24) & 0xFF;
//         final r = (argb >> 16) & 0xFF;
//         final g = (argb >> 8)  & 0xFF;
//         final b = (argb)       & 0xFF;
//         paint.color = Color.fromARGB(a, r, g, b);
//         canvas.drawRect(Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH), paint);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _PixelsPainter old) => old.pixels != pixels || old.grid != grid;
// }
class PlayNowButton extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onReset;
  final bool isLoading;
  final bool initialCompleted;

  const PlayNowButton(
      {super.key,
      this.onComplete,
      this.onReset,
      this.isLoading = false,
      this.initialCompleted = false});

  @override
  State<PlayNowButton> createState() => _PlayNowButtonState();
}

class _PlayNowButtonState extends State<PlayNowButton> {
  double _dragPercent = 0.0;
  bool _isCompleted = false;
  bool _localLoading = false;
  Timer? _loadingTimer;
  late final VoidCallback _resetListener;
  final double buttonWidth = 219;
  final double buttonHeight = 82;
  final double iconSize = 71;
  final double iconPadding = 5;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.initialCompleted;
    _dragPercent = widget.initialCompleted ? 1.0 : 0.0;
    _resetListener = () {
      if (!mounted) return;
      setState(() {
        _isCompleted = false;
        _dragPercent = 0.0;
      });
    };
    PlaybackState.resetNotifier.addListener(_resetListener);
  }

  void _startLoading() {
    setState(() => _localLoading = true);
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _localLoading = false);
    });
  }

  @override
  void dispose() {
    PlaybackState.resetNotifier.removeListener(_resetListener);
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxSlide = buttonWidth - iconSize - iconPadding * 2;
    final double iconLeft = iconPadding + (_dragPercent * maxSlide);
    final bool isAnyLoading = widget.isLoading || _localLoading;

    return UnconstrainedBox(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 219,
          maxWidth: 219,
          minHeight: 82,
          maxHeight: 82,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(41),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: buttonWidth,
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: _isCompleted ? const Color(0xFF93FF83) : Colors.black,
                  borderRadius: BorderRadius.circular(buttonHeight / 2),
                ),
              ),
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: _isCompleted
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      (_isCompleted && (widget.isLoading || _localLoading))
                          ? 'Playing'
                          : (_isCompleted ? 'End game' : 'Play Now'),
                      style: TextStyle(
                        color: _isCompleted ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: iconLeft,
                top: (buttonHeight - iconSize) / 2,
                child: AbsorbPointer(
                  absorbing: isAnyLoading,
                  child: GestureDetector(
                    onHorizontalDragUpdate: isAnyLoading
                        ? null
                        : (details) {
                            _dragPercent += details.primaryDelta! / maxSlide;
                            _dragPercent = _dragPercent.clamp(0.0, 1.0);
                            setState(() {});
                          },
                    onHorizontalDragEnd: isAnyLoading
                        ? null
                        : (_) {
                            if (_dragPercent >= 0.95 && !_isCompleted) {
                              setState(() {
                                _isCompleted = true;
                                _dragPercent = 1.0;
                              });
                              _startLoading();
                              widget.onComplete?.call();
                            } else if (_dragPercent <= 0.05 && _isCompleted) {
                              setState(() {
                                _isCompleted = false;
                                _dragPercent = 0.0;
                              });
                              _startLoading();
                              widget.onReset?.call();
                            } else {
                              setState(() {
                                _dragPercent = _isCompleted ? 1.0 : 0.0;
                              });
                            }
                          },
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: isAnyLoading
                          ? Center(
                              // Show a spinner during loading
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isCompleted ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/Vector.svg',
                              width: 71,
                              height: 71,
                              colorFilter: _isCompleted
                                  ? const ColorFilter.mode(
                                      Colors.black, BlendMode.srcIn)
                                  : null,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
