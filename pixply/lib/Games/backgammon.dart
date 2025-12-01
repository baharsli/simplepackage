import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:led_ble_lib/led_ble_lib.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:path/path.dart' show context;
import 'package:pixply/Settings/settings.dart';
import 'package:pixply/Settings/color_config.dart';
import 'package:pixply/Settings/displaymanager.dart';
import 'package:pixply/Settings/playback_state.dart';
import 'package:pixply/Settings/rotation_config.dart';
// import 'package:pixply/Tools/tools.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pixply/Likes/like_service.dart';

class Backgammon extends StatefulWidget {
  final LedBluetooth bluetooth;
  final bool isConnected;
  final String gameImage;
  final String gameTitle;
  final String gameId;

  const Backgammon(
      {super.key,
      required this.gameImage,
      required this.gameTitle,
      required this.bluetooth,
      required this.isConnected,
      required this.gameId});

  @override
  // ignore: library_private_types_in_public_api
  _BackgammonState createState() => _BackgammonState();
}

Widget buildMedia(String path, {double? width, double? height}) {
  return path.endsWith('.svg')
      ? SvgPicture.asset(path, width: width, height: height)
      : Image.asset(path, width: width, height: height);
}

class _BackgammonState extends State<Backgammon> {
  late LedBluetooth _bluetooth;
  bool _isConnected = false;
  int ledWidth = 56;
  int ledHeight = 56;
  int? expandedIndex;
  bool isHovered = false;
  bool isPressed = false;
  bool _isLoading = false;
  Color selectedColor = Colors.white;
  final List<String> _imagePaths = [
    'assets/Backgammon-game.png',
    'assets/logopixply.png',
  ];
  String lastImagePath = 'assets/Backgammon-game.png';
  final ScrollController _scrollCtrl = ScrollController();
  late final List<GlobalKey> _sectionKeys =
      List.generate(sections.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _bluetooth = widget.bluetooth;
    _isConnected = widget.isConnected;
    DisplayManager.initialize(_bluetooth);
    _initBluetooth();
    _prepareBoardForGame();
    // ColorConfig.addListener(_onColorChanged);
    // RotationStore.addListener(_onRotationChanged);
  }

  @override
  void dispose() {
    // ColorConfig.removeListener(_onColorChanged);
    // RotationStore.removeListener(_onRotationChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // void _onColorChanged(Color newColor) {
  //   if (mounted) {
  // _refreshImageWithNewColor();
  //   }
  // }
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
    _isConnected = _bluetooth.isConnected;
    if (!_isConnected) {
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

//image program
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

  // Future<void> _refreshImageWithNewColor() async {
  //   if (!_isConnected) {
  //     _showMessage("Device not connected");
  //     return;
  //   }

  //   try {
  //     // await _bluetooth.deleteAllPrograms();
  //     // await _bluetooth.updatePlaylistComplete();
  //     await _bluetooth.setRotation(RotationStore.selectedRotation);
  //     await Future.delayed(const Duration(milliseconds: 300));
  //     await _sendImageProgram(lastImagePath);

  //     DisplayManager.recordLastDisplay(
  //         path: lastImagePath, type: DisplayType.image);
  //   } catch (e) {
  //     _showMessage("Error refreshing image: $e");
  //   }
  // }

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
          "Be the first player to remove all your pieces from the board.",
      "image": "assets/Groupbackg.svg"
    },
    {
      "title": "Components",
      "icon": "assets/strategy.svg",
      "image": "assets/backgamoncolor.svg"
    },
    {
      "title": "Game Setup",
      "icon": "assets/preferences.svg",
      "description":
          ". Each player selects a color, either black or white.\n. The board's points are numbered from each player's perspective, starting at 1 (the farthest point) and ending at 24 (the point closest to them). The positions of the white and black pieces mirror each other.\n. Initial piece placement for each player is as follows:\n1. 2 pieces on point 1\n2. 5 pieces on point 12\n3. 3 pieces on point 16\n4. 5 pieces on point 19\n\n\nIn the following image, arrange your pieces to match the same setup as shown, ensuring they are placed on the points corresponding to your color.",
      "image": "assets/backgamonsetup.svg"
    },
    {
      "title": "Game play",
      "icon": "assets/war.svg",
      "description":
          "Each player rolls one die. The player with the higher number goes first, using the numbers on both dice to make their move.\n \nCheckers move forward according to the numbers rolled.",
      "image": "assets/backgamon1.svg",
      "extraImages": [
        {
          "image": "assets/backgamon2.svg",
          "description":
              ". The result of a single die roll determines the number of points a piece can move.\n. You can strategically decide which pieces to move based on your game plan. For example, you may use both dice to move the same piece twice or split the rolls to move two different pieces.\n. Doubles: If the same number is rolled on both dice, the player uses the number four times (e.g., rolling 3–3 means four 3-point moves).\n\n\nFor example, if the dice roll results in 'one' and 'two' the player has two options:\n1. Move a single piece by the combined total of the dice (three spaces).\n2. Move two separate pieces, one by the value of each die (one piece moves one space, and the other moves two spaces).\nThis choice allows for strategic flexibility based on the player's goals."
        },
        {
          "image": "assets/backgamon3.svg",
          "description":
              "Open Points:\nA piece can only land on:\n. A point with no pieces\n. A point occupied by your own pieces\n. A point with one opponent piece (resulting in a “hit”)\n\nHit:\nYou can hit an opponent’s piece if the destination point contains only one of their pieces. In this case, the opponent’s piece is removed from the board and placed in the bar area.\n\n\n1.bar(out)"
        },
        {
          "image": "assets/backgamon4.svg",
          "description":
              "If you have a checker on the bar, you cannot move any other checkers within the board until you reenter the checker into the game.\nTo reenter, the checker must start from point 1. On your turn, roll the dice to determine possible moves. You can reenter the checker only if one of the dice rolls corresponds to an open point (as explained in the previous section).\n\nOnce all of a player's pieces are in the Exit Zone, they can begin removing them from the board. To do so, the dice roll must match the number of the point where a piece is located or be higher than the highest occupied point in the Exit Zone.\n\n\n1.Black Exit Zone\n2.White Exit Zone"
        },
      ]
    },
    {
      "title": "Winning Conditions",
      "icon": "assets/winning.svg",
      "description":
          "The first player to successfully remove all of their pieces from the Exit Zone wins the game."
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
                          icon: SvgPicture.asset('assets/arrow.svg',
                              width: 36, height: 36),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        "Backgammon",
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
                            icon: SvgPicture.asset('assets/Setting.svg',
                                width: 36, height: 36),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SettingsPage(
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
                    child: Image.asset(widget.gameImage),
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
                          ValueListenableBuilder(
                            valueListenable: Hive.box('likesBox')
                                .listenable(keys: [widget.gameId]),
                            builder: (context, box, _) {
                              final liked = LikeService.isLiked(widget.gameId);
                              return GestureDetector(
                                onTap: () async {
                                  await LikeService.toggleLike(
                                    widget.gameId,
                                    name: widget.gameTitle,
                                    image: widget.gameImage,
                                  );
                                },
                                child: Icon(
                                  liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 5),
                          // const Text("435",
                          //     style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 20),
                          SvgPicture.asset("assets/Group.svg",
                              width: 18, height: 16.75),
                          const SizedBox(width: 5),
                          const Text("2",
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 130,
                      height: 39,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(19.5),
                      ),
                      child: const Text("Persia",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
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
                        "Born in Persia (circa 3000 BCE) as Nard, Backgammon is one of the oldest known board games, blending luck and strategy. It spread through the Middle East and Europe, becoming a timeless game of skill and fortune, played by kings, merchants, and noblemen for millennia.",
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

                              //
                              if (!isExpanded) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  final ctx =
                                      _sectionKeys[index].currentContext;
                                  if (ctx != null) {
                                    Scrollable.ensureVisible(
                                      ctx,
                                      alignment:
                                          0.0, // ابتدای سکشن بیاد بالای صفحه
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                });
                              }
                            },
                            child: Container(
                              key: _sectionKeys[index],
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
                                        ['icon'], // Use the icon from the data
                                    width: 32,
                                    height: 32,
                                  ),
                                  const SizedBox(
                                      width:
                                          10), // Spacing between icon and title
                                  Text(
                                    sections[index]['title']!,
                                    textAlign: TextAlign
                                        .left, // Align the title in the center
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
                          AnimatedSize(
                            // ✅ نرم‌تر شدن باز/بست
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: Container(
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
                                          const SizedBox(height: 35),
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
                          ),
                        ],
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 30),
                // const ToolsSection(),
                const SizedBox(
                    height:
                        150), // Adding empty space at the bottom of the page
              ],
            ),
          ),
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
