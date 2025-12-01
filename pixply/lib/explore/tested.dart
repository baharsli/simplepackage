import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:path/path.dart' show context;
import 'package:pixply/explore/info.dart';
import 'package:pixply/Settings/color_config.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:pixply/Settings/playback_state.dart';
import 'package:pixply/Settings/rotation_config.dart';

late LedBluetooth _bluetooth;
bool _isConnected = false;
int ledWidth = 56;
int ledHeight = 56;

class SixMens extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;
  final String gameImage;
  final String gameTitle;
  final String gameId;

  const SixMens(
      {super.key,
      required this.gameImage,
      required this.gameTitle,
      required this.bluetooth,
      required this.isConnected,
      required this.gameId});

  @override
  // ignore: library_private_types_in_public_api
  _SixMensState createState() => _SixMensState(); // ✅important
}

Widget buildMedia(String path, {double? width, double? height}) {
  return path.endsWith('.svg')
      ? SvgPicture.asset(path, width: width, height: height)
      : Image.asset(path, width: width, height: height);
}

class _SixMensState extends State<SixMens> {
  int? expandedIndex;
  bool isHovered = false;
  bool isPressed = false;
  bool _isLoading = false;
  Color selectedColor = Colors.white;
  final List<String> _imagePaths = [
    'assets/Six man morrise-game.png',
    'assets/logopixply.png',
  ];
  String lastImagePath = 'assets/Six man morrise-game.png';

  @override
  void initState() {
    super.initState();
    _bluetooth = widget.bluetooth;
    _isConnected = widget.isConnected;
    DisplayManager.initialize(_bluetooth);
    _initBluetooth();
    _prepareBoardForGame();
    ColorConfig.addListener(_onColorChanged);
    // RotationStore.addListener(_onRotationChanged);
  }

  @override
  void dispose() {
    ColorConfig.removeListener(_onColorChanged);
    // RotationStore.removeListener(_onRotationChanged);

    super.dispose();
  }

  void _onColorChanged(Color newColor) {
    if (mounted) {
      _refreshImageWithNewColor();
    }
  }
// void _onRotationChanged(ScreenRotation newRotation) {
//   if (mounted) {
//     _refreshImageWithNewColor();
//   }
// }

  Future<void> _prepareBoardForGame() async {
    if (_bluetooth.isConnected) {
      await _bluetooth.updatePlaylistComplete();
      debugPrint("✅ Board cleared when entering Adugo page");
    }
  }

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
      // final data = await rootBundle.load('assets/images/ic_launcher.png');
      // final bmp = data.buffer.asUint8List();
      // final bmp = Uint8List.fromList(List.filled(9454, 255));
      // Delete all programs
      // Create text program
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
      await Future.delayed(const Duration(milliseconds: 300));
      await _sendImageProgram(lastImagePath);

      DisplayManager.recordLastDisplay(
          path: lastImagePath, type: DisplayType.image);
    } catch (e) {
      _showMessage("Error refreshing image: $e");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  final List<Map<String, dynamic>> sections = [
    {
      "title": "Overview",
      "icon": "assets/school.svg",
      "description":
          "Reduce your opponent to fewer then three pieces or block all their possible move to win.",
      "image": "assets/Groupsixmens.svg"
    },
    {
      "title": "Components",
      "icon": "assets/strategy.svg",
      "image": "assets/Groupcolorsixmen.svg"
    },
    {
      "title": "Game Setup",
      "icon": "assets/preferences.svg",
      "description":
          ". Each player takes nine pieces of their chosen color( white and black).\n. The game begins within empty board, and players take turn placing their pieces on the board strategiclly.",
      "image": "assets/Groupsetupsix.svg"
    },
    {
      "title": "Game play",
      "icon": "assets/war.svg",
      "description":
          "Players decide who playes first usually determined by random means like rolling a die and chosen higher number)\n\nPlayers take turns placing their pieces on any empty point on the board.\n\n.  During the placement phase, players take turns placing their pieces one by one on empty intersections on the board.\n.  Note: Pieces cannot be moved during this phase until all have been successfully placed.\n.  Focus on placing your pieces to avoid enabling your opponent to form mills (three pieces in a straight line) while also attempting to block their potential mills.",
      "image": "assets/Gamesix1.svg",
      "extraImages": [
        {
          "image": "assets/Gameplaysix2.svg",
          "description":
              "After all pieces have been placed, players take turns moving their pieces.Standard Movement: A piece can only move to an adjacent empty intersection, following the lines on the board. The goal during this phase is often to form 'mills' (a straight line of three pieces) or block the opponent's movements."
        },
        {
          "image": "assets/Gameplaysix3.svg",
          "description":
              "Forming a Mill: A mill is a straight line of three of your pieces (horizontal or vertical). Forming a mill lets you remove one opponent's piece from the board.\nRules for Removal:\n.  You cannot remove a piece from a mill unless all opponent pieces are in mills.\n.  Removed pieces are permanently out of the game. \n. You don't need to fill the spot left by a removed piece. Each mill allows you to remove only one piece per turn. \nStrategy:\n.  Create new mills or break and reform existing ones to remove more pieces. \n. Target key pieces to block your opponent’s moves or mill formations."
        },
        {
          "image": "assets/Gameplay4.svg",
          "description":
              ". Flying Phase: (when a player has only three pieces left)\nPieces can 'fly' to any empty point on the board, not just adjacent ones."
        }
      ]
    },
    {
      "title": "Winning Conditions",
      "icon": "assets/winning.svg",
      "description":
          "A player wins by: Reducing the opponent to fewer than three pieces. Blocking all the opponent’s possible moves."
    },
  ];
  bool? isLiked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 71,
                        height: 71,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: IconButton(
                          icon: SvgPicture.asset('assets/close.svg',
                              width: 36, height: 36),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        "Six Men's Morris",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Container(
                        width: 71,
                        height: 71,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => isHovered = true),
                          onExit: (_) => setState(() => isHovered = false),
                          child: IconButton(
                            icon: SvgPicture.asset('assets/edit.svg',
                                width: 36, height: 36),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Info(
                                    bluetooth:
                                        _bluetooth, // ✅ your Bluetooth instance
                                    isConnected:
                                        _isConnected, // ✅ current connection state
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset('assets/Group 893.png'),
                    // borderRadius: BorderRadius.circular(54),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 161,
                      height: 39,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(19.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          //   GestureDetector(
                          //   onTap: () {
                          //   setState(() {
                          //     isLiked = !isLiked!;
                          //   });
                          // },
                          // child: Icon(
                          // (isLiked ?? false) ? Icons.favorite : Icons.favorite_border,
                          // color: Colors.white,
                          // size: 17,
                          //       ),
                          //     ),
                          const SizedBox(width: 5),
                          const Text("Europe",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(width: 20),
                          SvgPicture.asset("assets/Group.svg",
                              width: 18, height: 16.75),
                          const SizedBox(width: 5),
                          const Text("2",
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    // const SizedBox(width: 20),
                    // Container(
                    // width: 130,
                    // height: 39,
                    // alignment: Alignment.center,
                    // decoration: BoxDecoration(
                    // border: Border.all(color: Colors.grey),
                    // borderRadius: BorderRadius.circular(19.5),
                    //                 ),
                    // child: const Text("Europe", style: TextStyle(color: Colors.white, fontSize: 14)),
                    //               ),
                  ],
                ),

                const SizedBox(height: 35),

                // About Game Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "About Game",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 35),
                      const Text(
                        "Popular in medieval Europe (14th to 17th centuries), Six Men's Morris was a strategic board game played in countries like France, Italy, and England, where players aimed to form mills with six pieces on a simplified board.",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            height: 1.71),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 35),
                      const Text(
                        "Game Play Description",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 35),
                      const Text(
                        "In the heart of the dense forests of Brazil, a mighty jaguar embarked on a daring mission to rescue the captive prince of the Bororo tribe. He moved swiftly and silently along the moonlit paths until wild dogs loyal to the clan's enemies barred his way. Determined, Jaguar knew that he had to cleverly evade the dog traps and defeat a number of them to make his way. The jungle held its breath – could the jaguar outwit the dogs and reach the prince in time?",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            height: 1.71),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // Rulebook Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 35),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("Game Rulebook",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Poppins')),
                  ),
                ),

                const SizedBox(height: 35),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: List.generate(sections.length, (index) {
                      bool isExpanded = expandedIndex == index;
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                expandedIndex = isExpanded ? null : index;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .start, // Align items to start
                                children: [
                                  // Icon on the left
                                  SvgPicture.asset(
                                    sections[index]
                                        ['icon'], // use the 'icon' key
                                    width: 32,
                                    height: 32,
                                  ),
                                  const SizedBox(
                                      width:
                                          10), // Spacing between icon and title
                                  Text(
                                    sections[index]['title']!,
                                    textAlign: TextAlign
                                        .center, // Align the title in the center
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const Spacer(), // This pushes the icon to the far right of the Row
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: isExpanded
                                ? const EdgeInsets.all(15)
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? Color(0xFF4E4E4E)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: isExpanded
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (sections[index]['description'] !=
                                          null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 20),
                                          child: Text(
                                            sections[index]['description']!,
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontFamily: 'Poppins',
                                              height: 1.71,
                                            ),
                                          ),
                                        ),

                                      // Dotted line only for "Overview" section
                                      if (sections[index]['title'] ==
                                          'Overview') ...[
                                        const SizedBox(height: 20),
                                        const DottedLine(
                                          dashLength: 6,
                                          dashGapLength: 4,
                                          lineThickness: 1,
                                          dashColor: Colors.white30,
                                        ),
                                        if (sections[index]
                                            .containsKey('image')) ...[
                                          const SizedBox(height: 20),
                                          Center(
                                            child: buildMedia(
                                              sections[index]['image']!,
                                            ),
                                          ),
                                          const SizedBox(height: 35),
                                        ],
                                      ],
                                      if (sections[index]['title'] ==
                                          'Components') ...[
                                        const SizedBox(height: 20),
                                        if (sections[index]
                                            .containsKey('image')) ...[
                                          const SizedBox(height: 20),
                                          Center(
                                            child: buildMedia(
                                              sections[index]['image']!,
                                            ),
                                          ),
                                          const SizedBox(height: 35),
                                        ],
                                      ],
                                      // Game Setup & Game play specific padding
                                      if (sections[index]['title'] ==
                                              'Game Setup' ||
                                          sections[index]['title'] ==
                                              'Game play') ...[
                                        const SizedBox(
                                            height:
                                                50), // spacing between text & image
                                        Center(
                                            child: buildMedia(
                                                sections[index]['image']!)),
                                        const SizedBox(
                                            height: 50), // bottom padding
                                      ],
                                      // Winning Conditions specific padding
                                      if (sections[index]['title'] ==
                                          'Winning Conditions') ...[
                                        const SizedBox(height: 12),
                                        const SizedBox(
                                            height:
                                                35), // spacing between text & image
                                      ],

                                      if (sections[index]
                                          .containsKey('extraImages')) ...[
                                        // const SizedBox(height: 35),
                                        Column(
                                          children: (sections[index]
                                                  ['extraImages'] as List)
                                              .map<Widget>((extra) {
                                            return Column(
                                              children: [
                                                Text(
                                                  extra['description'],
                                                  textAlign: TextAlign.left,
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14,
                                                      fontFamily: 'Poppins',
                                                      height: 1.71),
                                                ),
                                                const SizedBox(height: 50),
                                                buildMedia(extra['image']),
                                                const SizedBox(height: 50),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  )
                                : null,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(
                    height:
                        135), // Adding empty space at the bottom of the page
              ],
            ),
          ),

// button
          Positioned(
            bottom: 35,
            left: 80,
            right: 80,
            child: PlayNowButton(
              isLoading: _isLoading,
              onComplete: () async {
                setState(() => _isLoading = true);
                try {
                  await Future.delayed(Duration(milliseconds: 100));
                  await _bluetooth.updatePlaylistComplete();
                  await _sendImageProgram(_imagePaths[0]);
                  await Future.delayed(
                      Duration(seconds: 5)); // simulate loading duration
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
                  await _bluetooth
                      .deleteAllPrograms(); // Clear display immediately
                  await _bluetooth.updatePlaylistComplete();
                  // Immediately send the next image
                  await _sendImageProgram(_imagePaths[1]);
                  await Future.delayed(Duration(seconds: 5));
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
}

class PlayNowButton extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onReset;
  final bool isLoading;

  const PlayNowButton(
      {super.key, this.onComplete, this.onReset, this.isLoading = false});

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
    _loadingTimer = Timer(const Duration(seconds: 3), () {
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
                duration: const Duration(milliseconds: 300),
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
                  duration: const Duration(milliseconds: 300),
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
