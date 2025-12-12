# Changelog
All important changes to this project are recorded in this file . 


## [Unreleased]
### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

---

## [0.1.0] - 2025-09-19
### Added 
terms & conditions 
Digital dice 

### Changed
How to fix ( starter)
Url & local ( pixstudio)
xx character pixstudio
info about & overview ( pixstudio)
Display color( pixstudio)
remove profile user and edite design

## [0.2.0] - 2025-09-27
### Added 
notification
about us page
add accecs 
Personal Data
add country for info page (pixstudio)
How to do pix studio
tooltipe icon info
Implement icon edit in My creation/game
popup for my creation
Terms and Conditions pixstudio

### Changed
aplay change filter category
language coming soon
display color & orientation for settings re design
re size icone
setting user account
tools coming soon
fix search bar
redesign like page
redesign your ideas page
redesign help center
redesign filter page

### Removed
delet number like

## [0.3.0] - 2025-10-1
### Added 

20 new games 
filter for new games 
add new data for games 

### Changed
applay changes for 50 game 
pixstudio password

## [0.4.1] - 2025-10-3

### Added 
add new settings for color picker in 70 games 
responsive for games.dart

### Changed
change file yourgame.dart
review and fix bug of games 
redesign for color picker 
compelet country in filter game 

## [0.5.2] - 2025-10-3

### Changed 
### Debug
contavt us 
your idea 
Faq
terms condition
rotation
colorpicker
like page popup
check connect
filter
rule book game
logo

## [0.6.2] - 2025-10-12

### Added 


### Changed 
button popup filter 
icon filter
rotertion 
color picker apply
pixstudio for design game 
send design at board 
your game button close 
how to do pixstudio video youtube 

### Debug
popup my creation 

### Removed

cancel in filter 
age range 
game basic info 
terms condition in pixstudio 

## [0.7.0] - 2025-10-22

### Added 


### Changed 
Terms check box just one (sixth task)
Text Connect page
size like icon and group 

### Debug
Color picker in pix studio 
how to do video 
apply color picker 
rotetion moqavem sazi and icon animation taqir jahat

## [0.7.1] - 2025-10-26

### Added 


### Changed 
Terms check box just one (sixth task)
Text Connect page
size like icon and group 

### Debug
Color picker in pix studio 
how to do video 
apply color picker 
rotetion moqavem sazi and icon animation taqir jahat


# Changelog

## [0.8.0] — 2025-11-07

### Added
- **Onboarding Instructions**: Added a new onboarding screen (`lib/onboarding/onboarding_instructions.dart`) with vector-based illustrations.
- **Activation Core Module**: Introduced `lib/core/activation.dart` to separate activation logic from UI components.
- **Instruction SVG Assets**:
  - `assets/activatecart.svg`
  - `assets/bluetoothinstruction.svg`
  - `assets/enrollinstruction.svg`
  - `assets/powerbankinstruction.svg`
- **Legacy Asset Support**: Added `assets/enrollinstruction.png` for backward compatibility.
- **Asset Audit Reports**:
  - `.unused_assets.txt`
  - `.unused_assets_report.csv` (includes file usage, size, and reference counts)

### Changed
- **Updated Core and UI Files** (minor code cleanup, import reordering, asset reference updates):
  - `lib/Settings/termsconditions.dart`
  - `lib/connected.dart`
  - `lib/connection.dart`
  - `lib/explore/design_game_page.dart`
  - `lib/explore/game_preview.dart`
  - `lib/explore/instructions.dart`
  - `lib/explore/mycreations.dart`
  - `lib/main.dart`
  - `lib/pixstudio_activation_patch.dart`
  - `lib/welcompixmat.dart`
- **Regenerated Desktop Plugin Registrants** for Flutter:
  - **Linux**:  
    `linux/flutter/generated_plugin_registrant.cc`,  
    `linux/flutter/generated_plugin_registrant.h`,  
    `linux/flutter/generated_plugins.cmake`
  - **macOS**:  
    `macos/Flutter/GeneratedPluginRegistrant.swift`
  - **Windows**:  
    `windows/flutter/generated_plugin_registrant.cc`,  
    `windows/flutter/generated_plugin_registrant.h`,  
    `windows/flutter/generated_plugins.cmake`
- **Line Ending Normalization (Windows)**:  
  Git adjusted LF → CRLF endings automatically. These warnings are informational only and do not affect functionality.

### Removed
- **Deprecated and Unused Raster Assets** cleaned up to reduce project size and standardize format:
  - `assets/Arrow 1.png`, `assets/Arrow 5.png`, `assets/Arrow 6.png`, `assets/Arrow 7.png`
  - `assets/Game Direction.png`, `assets/Gomokosetup.png`, `assets/Group 306.png`, `assets/Group 341.png`, `assets/Group 60.png`
  - `assets/Groupadugo.png`, `assets/Groupcolor.png`, `assets/Home.png`, `assets/Layer 1.jpg`, `assets/Nest.png`
  - `assets/Nine Mens Morrise-game.png`, `assets/Starting point.png`, `assets/dara1.png`, `assets/fivefield-game.png`
  - Deprecated launcher icons: `assets/images/ic_launcher.png`, `assets/images/ic_launcher2.png`

### Documentation
- Added full changelog entry for version `v0.8.0`, documenting onboarding module, activation refactor, and asset cleanup.

### Notes
- Commit: `f9c6e72` — *docs(changelog): add v0.8.0 notes*
- Tag: `v0.8.0` — *initial snapshot*
- If the tag did not push successfully, run:
  ```bash
  git push origin v0.8.0

# Changelog

## [0.9.0] — 2025-11-10

### Added
- **New App Icons (Multi-Platform Refresh)**  
  Introduced a complete redesign of Pixply’s app icon set with support for all density buckets and platforms:
  - **Android**:  
    - Foreground & monochrome assets for `hdpi`, `mdpi`, `xhdpi`, `xxhdpi`, and `xxxhdpi` resolutions  
    - Added adaptive icon XML: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`  
    - Added color resource file: `android/app/src/main/res/values/colors.xml`
  - **iOS**:  
    - Updated and expanded icon set in `ios/Runner/Assets.xcassets/AppIcon.appiconset`  
      including new sizes: 50×50, 57×57, 72×72 (both @1x and @2x)
  - **Assets**:  
    - `assets/app_icon.png`  
    - `assets/app_icon_fg.png`  
    - `assets/app_icon_mono.png`
- **New Page: Welcome Page**  
  Added a new start screen at `lib/start/welcomepage.dart` for improved user onboarding and navigation flow.

### Changed
- **Updated Flutter Project Files**  
  Minor updates to align with new icons and configurations:
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner.xcodeproj/project.pbxproj`
  - `lib/Settings/termsconditions.dart`
  - `lib/connected.dart`
  - `lib/connection.dart`
  - `lib/core/activation.dart`
  - `lib/main.dart`
  - `lib/onboarding/onboarding_instructions.dart`
- **Regenerated Plugin Registrants (Desktop)**  
  Updated auto-generated Flutter plugin registrants for Linux, macOS, and Windows platforms:
  - `linux/flutter/generated_plugin_registrant.cc`
  - `linux/flutter/generated_plugin_registrant.h`
  - `linux/flutter/generated_plugins.cmake`
  - `macos/Flutter/GeneratedPluginRegistrant.swift`
  - `windows/flutter/generated_plugin_registrant.cc`
  - `windows/flutter/generated_plugin_registrant.h`
  - `windows/flutter/generated_plugins.cmake`
- **Line Ending Normalization (Windows)**  
  Git automatically normalized LF → CRLF line endings in several files.  
  These warnings are informational only and do not affect code behavior.

### Removed
- No major file removals in this version. Minor cleanup handled automatically during asset updates.

### Documentation
- Added complete changelog entry for version `v0.9.0`, summarizing icon redesign, cross-platform asset updates, and onboarding improvements.

### Notes
- Commit: `1d6c4a3` — *docs(changelog): add v0.9.0 notes*  
- Tag: `v0.9.0` — *initial snapshot*  
- Pushed successfully to remote repository:

## [1.0.0] — 2025-11-12

### Added

lib/force_update_gate.dart: Introduced the force-update system to ensure users update to the latest app version.

android/app/proguard-rules.pro: Added ProGuard configuration for optimized and secure release builds.

pixply-release.keystore: Added keystore file for official app signing.

### Changed

Updated configuration files across Android, iOS, macOS, Windows, and Linux for compatibility with the stable release.

Improved structure of settings pages in lib/Settings/ including help.dart, termsconditions.dart, and youridea.dart.

Refactored main.dart and activation.dart to support the new activation logic.

### Removed

Deleted android/app/build.gradle.kts and reverted to the standard Gradle build structure.

## v1.0.11 — 2025-22-11

### Added
- Added SSH-based private Git dependency support for `led_ble_lib`.
- Added new version code `1.0.11+101` in `pubspec.yaml`.
- Added secure SSH deployment key configuration for Codemagic builds.

### Changed
- Migrated `led_ble_lib` from public HTTPS dependency to private SSH-based repository.
- Updated `pubspec.lock` after resolving SSH connection issues.
- Improved Git workflow to support submodule-aware commit structure (`pixply/` directory).

### Fixed
- Fixed local `flutter pub get` failure due to missing SSH host verification.
- Fixed Codemagic build errors related to private Git access.
- Resolved warnings and corrected line-ending consistency (LF → CRLF) across multiple platform plugin files.

### Notes
- This release ensures private package security while maintaining compatibility with Codemagic free plan.
- Next release should bump to `1.0.12+102` for production deployment.

## v1.0.43  — 2025-1-9
### Added


### Changed


### Fixed
- 

### Removed
perimision in the android manifest for instruction.dart pixstudio 
cammera and galery

### Note 
good for android 

## v1.0.44  — 2025-1-12
### Added
- reset button again

### Changed
- change display manager and setting for reset button 

### Fixed
- 

### Removed

### Note 
good for android 

## v1.0.45  — 2025-1-12
### Added
- new file code for reset button and reset button play now 

### Changed
- change display button play now  when the game reset

### Fixed
- 

### Removed

### Note 
good for android 

## v1.0.46  — 2025-1-12
### Added
- 

### Changed
- describtion perimision

### Fixed
- 

### Removed

perimision in info.plist 

### Note 
good for ios

## v1.0.47  — 2025-3-12
### Added
- 

### Changed
- change size box in help page for box answer 
- page displaymanager for ios and android 

### Fixed
- 

### Removed



### Note 
Test  for ios and android mixing v 38 and v 36

## v1.0.48  — 2025-8-12
### Added
- 

### Changed
- change  ['iledcolor-', 'pix']; in led ble base to  ['iledcolor-', 'Pix-'];


### Fixed
- 

### Removed



### Note 
Test  for ios and android mixing v 38 and v 36

## v1.0.49  — 2025-8-12
### Added
- 

### Changed
- change  ['iledcolor-', 'Pix-']; to 'Pix-';
- connection.dart & displaymanegar.dart back to v 45

### Fixed
- 

### Removed



### Note 
Test  for ios and android 

## v1.0.56  — 2025-8-12
### Added
- 

### Changed

- connection.dart & welcomepage.dart & led-ble-base.dart & led-screen.dart  checkblutooth.dart change  

### Fixed
- 

### Removed



### Note 
Good   for  android  v 57 not good for ios 

## v1.0.59  — 2025-9-12
### Added
- 

### Changed




### Fixed
- pixstudio color game problem 
time button play 
reset button 
logo when you connect to board 
filter scan devise ble
terms problem 
change color 

### Removed



### Note 
Good   for  ios 

## v1.0.60  — 2025-9-12
### Added
- 

### Changed




### Fixed
image for game

### Removed
zohnahl game


### Note 
Good   for  ios 

## v1.0.61  — 2025-10-12
### Added
- 

### Changed

color config and settings for color change game & image of game change 




### Fixed


### Removed



### Note 
color test good for android but image game have problem 

## v1.0.62  — 2025-11-12
### Added
- 

### Changed




### Fixed
image for game

### Removed



### Note 
Test  for  ios and android   => good for android 
just name game snake and laders 

## v1.0.63  — 2025-12-12
### Added
- 

### Changed




### Fixed
name game snake and laders 

### Removed



### Note 
Test  for  ios 

