import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pixply/explore/game_creation_store.dart';
import 'package:pixply/explore/game_preview.dart';
import 'package:flutter/services.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:permission_handler/permission_handler.dart';

class GameInstructionPage extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;
  final int gridSize;
  final List<int> pixelsArgb;
  final bool testedOnBoard;
  
  const GameInstructionPage({
    super.key,
    required this.bluetooth,
    required this.isConnected,
    required this.gridSize,
    required this.pixelsArgb,
    this.testedOnBoard = false,
  });

  @override
  State<GameInstructionPage> createState() => _GameInstructionPageState();
}

class _GameInstructionPageState extends State<GameInstructionPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  File? _selectedFile;

  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

bool get _isFormValid {
  final hasDesc = _descriptionController.text.trim().isNotEmpty;
  final hasUrl  = _urlController.text.trim().isNotEmpty;
  return hasDesc || hasUrl || (_selectedFile != null);
}
static const int descriptionMaxLength = 300;

final Map<String, List<String>> _tips = {
  "Game Play Description":["Description","Write main rules, phases/rounds and the duration of each round clearly and briefly."],
  
  "Instruction Video URL":["Video URL", "If you have an instructional video, enter a valid URL (https://) so users can see how to play."]
      ,
};
// accec 
Future<bool> _ensureUploadPermissions({
  required bool needsCamera,
  required bool needsPhotoLibrary,
  bool needsMicrophone = false, // set true if recording video with audio
}) async {
  if (kIsWeb) return true; // Web handles via browser picker, no runtime perms

  // Desktop (macOS/Windows/Linux): generally no runtime permission required
  if (!Platform.isAndroid && !Platform.isIOS) return true;

  final List<Permission> toRequest = [];

  if (needsCamera) {
    toRequest.add(Permission.camera);
    if (Platform.isIOS && needsMicrophone) {
      // On iOS, camera video often needs microphone too
      toRequest.add(Permission.microphone);
    }
  }

  if (needsPhotoLibrary) {
    if (Platform.isIOS) {
      toRequest.add(Permission.photos); // iOS photo library
    } else if (Platform.isAndroid) {
      // Android: rely on system Photo Picker (no runtime storage permission).
      // Keep empty so we don't request READ_MEDIA_* / READ_EXTERNAL_STORAGE.
    }
  }

  if (toRequest.isEmpty) return true;

  final statuses = await toRequest.request();

  bool allGranted = true;
  for (final p in toRequest) {
    final s = statuses[p];
    if (s == null || !s.isGranted) {
      allGranted = false;
    }
  }

  if (!allGranted) {
    // If any permanently denied, guide to settings with a friendly dialog/snackbar
    final permanentlyDenied = toRequest.any((p) => statuses[p]?.isPermanentlyDenied == true);

    if (permanentlyDenied) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Permission required',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            content: const Text(
              'To upload photos or videos, please enable access in Settings.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                },
                child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission not granted')),
        );
      }
    }
  }

  return allGranted;
}


  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
    _urlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _urlController.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  TextStyle _textStyle(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  bool _isImagePath(String p) {
    final ext = p.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png');
  }

  bool _isVideoPath(String p) {
    final ext = p.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi');
  }

  Future<void> _onRelease(BuildContext context) async {
  final store = context.read<GameCreationStore>();
    String? persistedPath;
  if (_selectedFile != null && !kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();      // :contentReference[oaicite:5]{index=5}
    final dest = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.path.split('/').last}');
    await _selectedFile!.copy(dest.path);
    persistedPath = dest.path;
  } else {
     persistedPath = _selectedFile?.path;
      }
    store.setInstruction(
    gameplayDescription: _descriptionController.text.trim(),
    videoUrl: _urlController.text.trim(),
    localMediaPath: persistedPath,
  );
  final box = Hive.box<Map>('my_creations');
  final id  = DateTime.now().millisecondsSinceEpoch.toString();
final snap = store.current().toJson()
  ..addAll({"id": id, "createdAt": DateTime.now().toIso8601String()});
await box.put(id, Map<String, dynamic>.from(snap));

        // ✅
  if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>  GamePreviewPage(
          bluetooth: widget.bluetooth,
          isConnected: widget.isConnected,
          alreadyOnBoard: widget.testedOnBoard,
        ),
        settings: RouteSettings(arguments: id),
      ),
    );
}
  Future<void> _initVideo(File file) async {
    _videoCtrl?.dispose();
    _videoCtrl = VideoPlayerController.file(file);
    try {
      await _videoCtrl!.initialize();
      await _videoCtrl!.pause();
      setState(() => _videoReady = true);
    } catch (_) {
      setState(() => _videoReady = false);
    }
  }

  Future<void> _pickFile() async {

  final ok = await _ensureUploadPermissions(
    needsCamera: false,
    needsPhotoLibrary: true,
  );
  if (!ok) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
        _videoReady = false;
      });
      if (_isVideoPath(file.path)) {
        await _initVideo(file);
      }
    }
  }

  Widget _uploadBox() {
    return Center(
      child: GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: 338,
          height: 173,
          decoration: BoxDecoration(
            color: const Color(0xFF2E2E2E),
            borderRadius: BorderRadius.circular(15),
          ),
          clipBehavior: Clip.antiAlias,
          child: _selectedFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset('assets/upload.svg',
                        width: 36, height: 36),
                    const SizedBox(height: 8),
                    Text("Upload From My Device", style: _textStyle(14)),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isImagePath(_selectedFile!.path))
                      Image.file(_selectedFile!, fit: BoxFit.cover)
                    else if (_isVideoPath(_selectedFile!.path))
                      (_videoCtrl != null && _videoReady)
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoCtrl!.value.size.width,
                                height: _videoCtrl!.value.size.height,
                                child: VideoPlayer(_videoCtrl!),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6)
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedFile!.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _textStyle(12, color: Colors.white70),
                              ),
                            ),
                            if (_isVideoPath(_selectedFile!.path) &&
                                _videoCtrl != null)
                              IconButton(
                                icon: Icon(
                                  _videoCtrl!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  if (_videoCtrl!.value.isPlaying) {
                                    await _videoCtrl!.pause();
                                  } else {
                                    await _videoCtrl!.play();
                                  }
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.upload_file,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 71,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 71,
              height: 71,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromRGBO(51, 51, 51, 1),
              ),
              child: Center(
                child:
                    SvgPicture.asset('assets/back.svg', width: 36, height: 36),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Game Instruction",
              style: _textStyle(24, weight: FontWeight.w600),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
Widget _infoIcon(String key, {bool dark = true , }) {
  final pair = _tips[key];
  final title = (pair != null && pair.isNotEmpty) ? pair[0] : key;
  final body  = (pair != null && pair.length > 1) ? pair[1] : "Info";

  final bg = dark ? const Color(0xFF2A2A2F) : Colors.white;      
  final fg = dark ? Colors.white : const Color(0xFF1D1D1F);
  
  return JustTheTooltip(
    preferredDirection: AxisDirection.up,  
    tailLength: 10,
    tailBaseWidth: 18,
    backgroundColor: bg,
    isModal: true,
    margin: const EdgeInsets.all(12),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: DefaultTextStyle(
          style: TextStyle(color: fg, height: 1.35, fontFamily: 'Poppins'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  )),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    
    child: Semantics(
      label: 'Info: $key',
      button: true,
      child: SizedBox(
        width: 48, height: 48,
        child: Center(
          child: SvgPicture.asset(
            "assets/info.svg",
            width: 25, height: 25,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            semanticsLabel: 'Info',
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("Game Play Description", style: _textStyle(20)),
                          const SizedBox(width: 6),
                         _infoIcon("Game Play Description"),
                        ],
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _descriptionController,
                        style: _textStyle(14),
  keyboardType: TextInputType.multiline,
  minLines: 1,
  maxLines: null, // allow dynamic growth
  maxLength: descriptionMaxLength,
  maxLengthEnforcement: MaxLengthEnforcement.enforced,
  inputFormatters: [
    LengthLimitingTextInputFormatter(descriptionMaxLength),
  ],
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.green)),
                                counterText: '',
                        ),
                      ),
                      const SizedBox(height: 4),
                   Text(
  "${_descriptionController.text.length}/$descriptionMaxLength ${_descriptionController.text.length == 1 ? 'Character' : 'Characters'}",
  style: _textStyle(12, color: Colors.white70),
),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Text("Instruction Video URL", style: _textStyle(20)),
                          const SizedBox(width: 6),
                          _infoIcon("Instruction Video URL"),
                        ],
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _urlController,
                        style: _textStyle(14),
                        decoration: InputDecoration(
                          hintText: "https://",
                          hintStyle: _textStyle(14, color: Colors.white38),
                          border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _uploadBox(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 336,
                  height: 82,
                  child: ElevatedButton(
                    onPressed: _isFormValid
                      ? () => _onRelease(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B2B2B),
                      disabledBackgroundColor: const Color(0xFF2E2E2E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                    ),
                    child: Text(
                      "Release My Game",
                      style: _textStyle(
                        20,
                        weight: FontWeight.w600,
                        color: _isFormValid
                            ? const Color(0xFF59E37A)
                            : Colors.white,
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
