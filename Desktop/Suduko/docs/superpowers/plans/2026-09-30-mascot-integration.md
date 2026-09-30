# Mascot Buddy Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Sudoku owl mascot from a passive status icon into a lively, sound-synchronized **Mascot Buddy Companion** that players bond with. When the game opens, the owl swoops into the screen with physics-based flight and audio. During gameplay, it sits on a prominent companion perch, reacts with empathetic speech bubbles ("Nice spot!", "Take your time!"), bounces playfully when tapped with cheerful chirps, celebrates combos/streaks, and dances on victory.

**Architecture:** 
- **Assets:** 6 high-resolution mascot sprite states (`idle`, `thinking`, `happy`, `mistake`, `hint`, `win`) in `sudoku_app/assets/images/mascot/`.
- **Audio-Visual Sync:** Synchronized audio hooks in `AudioController` for swooping flight, landing chirps, tap bounces, and streak celebrations.
- **Flight Physics:** `FlyingMascotEntrance` featuring curved flight path (`Curves.easeOutBack`), wing-flutter micro-rotation oscillation, landing squash-and-stretch bounce, and instant tap-to-skip.
- **Buddy Mechanics & Speech:** `MascotBuddyPerch` with animated `MascotSpeechBubble` providing empathetic feedback (never punitive error checking), streak encouragement, and tap interactions.
- **State Management:** `MascotController` (`ChangeNotifier`) that manages moods, streak reactions, and speech timers, decoupled from Sudoku puzzle generation.
- **Settings & Persistence:** User toggle in `SettingsController` to enable/disable the mascot companion with instant reactivity.

**Tech Stack:** Flutter / Dart, `just_audio`, `ChangeNotifier`, `CurvedAnimation`, `SharedPreferences`, `flutter_screenutil`.

**Spec Reference:** `/Users/keshavgoyal/Desktop/Suduko/sudoku_app/MASCOT_UI_UX_README.md`

## Task Status Matrix

| Task | Title | Status |
|---|---|---|
| Task 1 | Asset Migration and Pubspec Configuration | [x] Completed |
| Task 2 | Mascot Mood Model and MascotController | [x] Completed |
| Task 3 | Interactive MascotWidget with Breathing Micro-Animation | [x] Completed |
| Task 4 | Basic Mascot Integration in GameScreen | [x] Completed (Base) |
| Task 5 | Mascot Integration in HomeScreen | [x] Completed |
| Task 6 | Settings Option for Mascot (Toggle Show/Hide) | [x] Completed |
| Task 7 | Sound-Synchronized Mascot Audio System | [x] Completed |
| Task 8 | Flying Entrance Swoop Animation Widget (`FlyingMascotEntrance`) | [x] Completed |
| Task 9 | Prominent Buddy Companion Perch & Speech Bubble System | [x] Completed |
| Task 10 | Connect Mascot Buddy & Flying Entrance to GameScreen | [x] Completed |
| Task 11 | Settings Option & Skip Toggles Verification | [x] Completed |
| Task 12 | Visual & Responsive Verification on Android Emulator | [x] Completed |

## Review Focus

1. **Audio-Visual Synchronization:** Ensure flying swoop sound starts immediately on screen mount and landing chirp triggers exactly at the moment of touchdown.
2. **Screen Real Estate & Responsive Layout:** Mascot buddy perch (52–60px) must look prominent and welcoming without causing `A RenderFlex overflowed...` on small 16:9 phones.
3. **Empathetic Buddy Feedback:** Mascot tone must feel like a supportive puzzle friend (Duolingo style), not an error validator.
4. **Performance & Battery:** 60 FPS fluid rendering using native Flutter transforms without bulky external animation runtimes.
5. **Speedrun Friendly:** Fast tap anywhere immediately skips the entrance animation so speed solvers are never delayed.

---

### Task 1: Asset Migration and Pubspec Configuration

**Files:**
- Create: `sudoku_app/assets/images/mascot/mascot_idle.png` (copy from `assets/images/mascot/mascot_idle.png`)
- Create: `sudoku_app/assets/images/mascot/mascot_thinking.png` (copy from `assets/images/mascot/mascot_thinking.png`)
- Create: `sudoku_app/assets/images/mascot/mascot_happy.png` (copy from `assets/images/mascot/mascot_happy.png`)
- Create: `sudoku_app/assets/images/mascot/mascot_mistake.png` (copy from `assets/images/mascot/mascot_mistake.png`)
- Create: `sudoku_app/assets/images/mascot/mascot_hint.png` (copy from `assets/images/mascot/mascot_hint.png`)
- Create: `sudoku_app/assets/images/mascot/mascot_win.png` (copy from `assets/images/mascot/mascot_win.png`)
- Modify: `sudoku_app/pubspec.yaml:70-73`
- Test: `sudoku_app/test/mascot_assets_test.dart`

**Interfaces:**
- Consumes: PNG files located at `/Users/keshavgoyal/Desktop/Suduko/assets/images/mascot/`
- Produces: Asset keys accessible via `assets/images/mascot/*.png`

- [ ] **Step 1: Write the failing asset verification test**

```dart
// sudoku_app/test/mascot_assets_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 6 mascot asset images exist in sudoku_app/assets/images/mascot/', () {
    const assets = [
      'assets/images/mascot/mascot_idle.png',
      'assets/images/mascot/mascot_thinking.png',
      'assets/images/mascot/mascot_happy.png',
      'assets/images/mascot/mascot_mistake.png',
      'assets/images/mascot/mascot_hint.png',
      'assets/images/mascot/mascot_win.png',
    ];

    for (final path in assets) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'Missing asset: $path');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/mascot_assets_test.dart`
Expected: FAIL with "Missing asset: assets/images/mascot/mascot_idle.png"

- [ ] **Step 3: Copy images and update pubspec.yaml**

1. Create directory `sudoku_app/assets/images/mascot/`
2. Copy the 6 PNG files:
   `cp assets/images/mascot/*.png sudoku_app/assets/images/mascot/`
3. Update `sudoku_app/pubspec.yaml` under `assets:`:
```yaml
  assets:
    - assets/audio/
    - assets/images/
    - assets/images/mascot/
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/mascot_assets_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/assets/images/mascot/ sudoku_app/pubspec.yaml sudoku_app/test/mascot_assets_test.dart
git commit -m "feat(mascot): add mascot sprite assets and declare in pubspec"
```

---

### Task 2: Mascot Mood Model and MascotController

**Files:**
- Create: `sudoku_app/lib/core/mascot_controller.dart`
- Test: `sudoku_app/test/mascot_controller_test.dart`

**Interfaces:**
- Consumes: None (independent state manager)
- Produces:
  - `enum MascotMood { idle, thinking, happy, mistake, hint, win }`
  - `class MascotController extends ChangeNotifier`
    - `MascotMood get mood`
    - `String get assetPath`
    - `void setMood(MascotMood mood, {Duration? duration})`
    - `void onCellSelected(bool isSelected)`
    - `void onCorrectMove()`
    - `void onMistake()`
    - `void onHintUsed()`
    - `void onGameWon()`
    - `void onGameOver()`
    - `void reset()`
    - `void dispose()`

- [ ] **Step 1: Write the failing MascotController unit test**

```dart
// sudoku_app/test/mascot_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/core/mascot_controller.dart';

void main() {
  group('MascotController', () {
    late MascotController controller;

    setUp(() {
      controller = MascotController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial mood is idle with correct asset path', () {
      expect(controller.mood, MascotMood.idle);
      expect(controller.assetPath, 'assets/images/mascot/mascot_idle.png');
    });

    test('onCellSelected changes mood to thinking when selected and back to idle when unselected', () {
      controller.onCellSelected(true);
      expect(controller.mood, MascotMood.thinking);
      expect(controller.assetPath, 'assets/images/mascot/mascot_thinking.png');

      controller.onCellSelected(false);
      expect(controller.mood, MascotMood.idle);
    });

    test('onCorrectMove sets mood to happy and returns to idle after timeout', () async {
      controller.onCorrectMove(duration: const Duration(milliseconds: 50));
      expect(controller.mood, MascotMood.happy);
      expect(controller.assetPath, 'assets/images/mascot/mascot_happy.png');

      await Future.delayed(const Duration(milliseconds: 70));
      expect(controller.mood, MascotMood.idle);
    });

    test('onMistake sets mood to mistake', () {
      controller.onMistake();
      expect(controller.mood, MascotMood.mistake);
      expect(controller.assetPath, 'assets/images/mascot/mascot_mistake.png');
    });

    test('onHintUsed sets mood to hint', () {
      controller.onHintUsed();
      expect(controller.mood, MascotMood.hint);
      expect(controller.assetPath, 'assets/images/mascot/mascot_hint.png');
    });

    test('onGameWon sets mood to win permanently', () {
      controller.onGameWon();
      expect(controller.mood, MascotMood.win);
      expect(controller.assetPath, 'assets/images/mascot/mascot_win.png');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/mascot_controller_test.dart`
Expected: FAIL with compilation error "Cannot find 'package:sudoku_app/core/mascot_controller.dart'"

- [ ] **Step 3: Write minimal MascotController implementation**

```dart
// sudoku_app/lib/core/mascot_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

enum MascotMood {
  idle,
  thinking,
  happy,
  mistake,
  hint,
  win,
}

extension MascotMoodAsset on MascotMood {
  String get assetPath {
    switch (this) {
      case MascotMood.idle:
        return 'assets/images/mascot/mascot_idle.png';
      case MascotMood.thinking:
        return 'assets/images/mascot/mascot_thinking.png';
      case MascotMood.happy:
        return 'assets/images/mascot/mascot_happy.png';
      case MascotMood.mistake:
        return 'assets/images/mascot/mascot_mistake.png';
      case MascotMood.hint:
        return 'assets/images/mascot/mascot_hint.png';
      case MascotMood.win:
        return 'assets/images/mascot/mascot_win.png';
    }
  }
}

class MascotController extends ChangeNotifier {
  MascotMood _mood = MascotMood.idle;
  bool _isCellSelected = false;
  Timer? _revertTimer;
  bool _isLocked = false; // Locked on game won or game over

  MascotMood get mood => _mood;
  String get assetPath => _mood.assetPath;

  void setMood(MascotMood newMood, {Duration? duration}) {
    if (_isLocked && newMood != MascotMood.idle) return;

    _revertTimer?.cancel();
    _revertTimer = null;
    _mood = newMood;
    notifyListeners();

    if (duration != null) {
      _revertTimer = Timer(duration, () {
        if (!_isLocked) {
          _mood = _isCellSelected ? MascotMood.thinking : MascotMood.idle;
          notifyListeners();
        }
      });
    }
  }

  void onCellSelected(bool isSelected) {
    _isCellSelected = isSelected;
    if (_revertTimer != null || _isLocked) return;

    final target = isSelected ? MascotMood.thinking : MascotMood.idle;
    if (_mood != target) {
      _mood = target;
      notifyListeners();
    }
  }

  void onCorrectMove({Duration duration = const Duration(milliseconds: 1400)}) {
    setMood(MascotMood.happy, duration: duration);
  }

  void onMistake({Duration duration = const Duration(milliseconds: 1800)}) {
    setMood(MascotMood.mistake, duration: duration);
  }

  void onHintUsed({Duration duration = const Duration(milliseconds: 2200)}) {
    setMood(MascotMood.hint, duration: duration);
  }

  void onGameWon() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _mood = MascotMood.win;
    notifyListeners();
  }

  void onGameOver() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _mood = MascotMood.mistake;
    notifyListeners();
  }

  void reset() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = false;
    _isCellSelected = false;
    _mood = MascotMood.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/mascot_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/core/mascot_controller.dart sudoku_app/test/mascot_controller_test.dart
git commit -m "feat(mascot): add MascotMood and MascotController with auto-reverting states"
```

---

### Task 3: Interactive MascotWidget with Breathing Micro-Animation

**Files:**
- Create: `sudoku_app/lib/widgets/mascot_widget.dart`
- Test: `sudoku_app/test/mascot_widget_test.dart`

**Interfaces:**
- Consumes: `MascotController`, `MascotMood`, `MascotMoodAsset`
- Produces:
  - `class MascotWidget extends StatefulWidget`
    - `final MascotController? controller`
    - `final MascotMood? staticMood`
    - `final double size`
    - `final VoidCallback? onTap`
    - `final bool enableBreathing`

- [ ] **Step 1: Write the failing widget test**

```dart
// sudoku_app/test/mascot_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/core/mascot_controller.dart';
import 'package:sudoku_app/widgets/mascot_widget.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('MascotWidget renders static mood image', (tester) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        const MascotWidget(
          staticMood: MascotMood.win,
          size: 100,
          enableBreathing: false,
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);
    final image = tester.widget<Image>(imageFinder);
    expect((image.image as AssetImage).assetName, 'assets/images/mascot/mascot_win.png');
  });

  testWidgets('MascotWidget reacts to controller mood changes', (tester) async {
    final controller = MascotController();

    await tester.pumpWidget(
      createWidgetUnderTest(
        MascotWidget(
          controller: controller,
          size: 60,
          enableBreathing: false,
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    var image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/mascot/mascot_idle.png');

    controller.onMistake();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // allow crossfade animation

    image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/mascot/mascot_mistake.png');
    controller.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/mascot_widget_test.dart`
Expected: FAIL with compilation error "Cannot find 'package:sudoku_app/widgets/mascot_widget.dart'"

- [ ] **Step 3: Write MascotWidget implementation**

```dart
// sudoku_app/lib/widgets/mascot_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/mascot_controller.dart';
import '../core/settings_controller.dart';

class MascotWidget extends StatefulWidget {
  final MascotController? controller;
  final MascotMood? staticMood;
  final double size;
  final VoidCallback? onTap;
  final bool enableBreathing;

  const MascotWidget({
    super.key,
    this.controller,
    this.staticMood,
    this.size = 56,
    this.onTap,
    this.enableBreathing = true,
  }) : assert(controller != null || staticMood != null,
            'Either controller or staticMood must be provided');

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _breathingAnimation = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }

    widget.controller?.addListener(_onControllerChanged);
    SettingsController.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    SettingsController.instance.removeListener(_onSettingsChanged);
    _breathingController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  MascotMood get _currentMood =>
      widget.staticMood ?? widget.controller?.mood ?? MascotMood.idle;

  @override
  Widget build(BuildContext context) {
    if (!SettingsController.instance.mascotEnabled) {
      return const SizedBox.shrink();
    }

    final double effectiveSize = widget.size.w;

    Widget mascotImage = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Image.asset(
        _currentMood.assetPath,
        key: ValueKey<String>(_currentMood.assetPath),
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );

    Widget content = widget.enableBreathing
        ? AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _breathingAnimation.value),
                child: child,
              );
            },
            child: mascotImage,
          )
        : mascotImage;

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/mascot_widget_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/widgets/mascot_widget.dart sudoku_app/test/mascot_widget_test.dart
git commit -m "feat(mascot): create animated MascotWidget with breathing effect and crossfade"
```

---

### Task 4: Connect Mascot to GameScreen and Game Events

**Files:**
- Modify: `sudoku_app/lib/screens/game_screen.dart`
- Test: `sudoku_app/test/game_screen_mascot_test.dart`

**Interfaces:**
- Consumes: `MascotController`, `MascotWidget`, `GameController`
- Produces: Live animated mascot integrated into:
  - Game screen status row (`_buildStatusLine`)
  - Victory Overlay (`_buildVictoryOverlay`)
  - Game Over Overlay (`_buildGameOverOverlay`)

- [ ] **Step 1: Write the failing GameScreen Mascot integration test**

```dart
// sudoku_app/test/game_screen_mascot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/core/sudoku_generator.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/widgets/mascot_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'mascotEnabled': true,
    });
  });

  testWidgets('GameScreen contains MascotWidget in gameplay', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, _) => const MaterialApp(
          home: GameScreen(
            difficulty: SudokuDifficulty.easy,
          ),
        ),
      ),
    );

    // Let initialization finish
    await tester.pumpAndSettle();

    expect(find.byType(MascotWidget), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/game_screen_mascot_test.dart`
Expected: FAIL with "Expected: findsWidgets, Actual: 0"

- [ ] **Step 3: Modify GameScreen to initialize and display MascotWidget**

1. In `_GameScreenState`:
   - Add `late MascotController _mascotController;`
   - In `initState()`:
     ```dart
     _mascotController = MascotController();
     ```
   - In `dispose()`:
     ```dart
     _mascotController.dispose();
     ```
2. In `_onGameStateChanged()`:
   - Handle events:
     ```dart
     if (_controller.isGameWon) {
       _mascotController.onGameWon();
     } else if (_controller.isGameOver) {
       _mascotController.onGameOver();
     } else {
       _mascotController.onCellSelected(_controller.selectedCell != null);
     }
     ```
3. In `_handleHint()` or where hint is executed:
   - Trigger `_mascotController.onHintUsed();`
4. In mistake / commit handling:
   - When wrong number entered, trigger `_mascotController.onMistake();`
   - When correct number entered, trigger `_mascotController.onCorrectMove();`
5. In `_buildStatusLine`:
   - Place a `MascotWidget(controller: _mascotController, size: 36.w)` in the center between mistakes count and difficulty label.
6. In `_buildVictoryOverlay`:
   - Replace or enhance the trophy icon with `MascotWidget(staticMood: MascotMood.win, size: 108.w, enableBreathing: true)`.
7. In `_buildGameOverOverlay`:
   - Replace or enhance sad icon with `MascotWidget(staticMood: MascotMood.mistake, size: 96.w, enableBreathing: false)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/game_screen_mascot_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/screens/game_screen.dart sudoku_app/test/game_screen_mascot_test.dart
git commit -m "feat(mascot): integrate reactive mascot into GameScreen and victory/loss modals"
```

---

### Task 5: Mascot Integration in HomeScreen

**Files:**
- Modify: `sudoku_app/lib/screens/home_screen.dart`
- Test: `sudoku_app/test/home_screen_mascot_test.dart`

**Interfaces:**
- Consumes: `MascotController`, `MascotWidget`, `HomeScreen`
- Produces: Welcoming animated mascot in the center brand section of HomeScreen with tap interaction (winks / smiles on tap).

- [ ] **Step 1: Write the failing HomeScreen Mascot test**

```dart
// sudoku_app/test/home_screen_mascot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/screens/home_screen.dart';
import 'package:sudoku_app/widgets/mascot_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_saved_game': false,
      'mascotEnabled': true,
    });
  });

  testWidgets('HomeScreen displays MascotWidget in brand area', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, _) => const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(MascotWidget), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/home_screen_mascot_test.dart`
Expected: FAIL with "Expected: findsOneWidget, Actual: 0"

- [ ] **Step 3: Modify HomeScreen to integrate MascotWidget**

1. In `_HomeScreenState`:
   - Add `late MascotController _homeMascotController;`
   - In `initState()`:
     ```dart
     _homeMascotController = MascotController();
     ```
   - In `dispose()`:
     ```dart
     _homeMascotController.dispose();
     ```
2. In `_HomeScreenState.build()`, in the Center Brand Graphic section:
   - Add `MascotWidget`:
     ```dart
     MascotWidget(
       controller: _homeMascotController,
       size: 80.w,
       onTap: () {
         AudioController.instance.playClick();
         _homeMascotController.setMood(
           MascotMood.happy,
           duration: const Duration(milliseconds: 1500),
         );
       },
     ),
     SizedBox(height: 12.h),
     ```
3. Keep the layout balanced with responsive spacing using `ScreenUtil`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/home_screen_mascot_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/screens/home_screen.dart sudoku_app/test/home_screen_mascot_test.dart
git commit -m "feat(mascot): add interactive welcome mascot to HomeScreen"
```

---

### Task 6: Settings Option for Mascot (Toggle Show/Hide)

**Files:**
- Modify: `sudoku_app/lib/core/settings_controller.dart`
- Modify: `sudoku_app/lib/screens/settings_screen.dart`
- Test: `sudoku_app/test/settings_mascot_test.dart`

**Interfaces:**
- Consumes: `SettingsController`, `SharedPreferences`
- Produces:
  - `bool get mascotEnabled`
  - `Future<void> setMascotEnabled(bool value)`
  - Switch tile in `SettingsScreen`

- [ ] **Step 1: Write the failing SettingsController Mascot test**

```dart
// sudoku_app/test/settings_mascot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/core/settings_controller.dart';

void main() {
  test('SettingsController defaults mascotEnabled to true and persists changes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController.instance;
    await Future.delayed(const Duration(milliseconds: 50));

    expect(settings.mascotEnabled, isTrue);

    await settings.setMascotEnabled(false);
    expect(settings.mascotEnabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('mascotEnabled'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/settings_mascot_test.dart`
Expected: FAIL with "The getter 'mascotEnabled' isn't defined for the class 'SettingsController'"

- [ ] **Step 3: Update SettingsController and SettingsScreen**

1. In `sudoku_app/lib/core/settings_controller.dart`:
   - Add field: `bool _mascotEnabled = true;`
   - Add getter: `bool get mascotEnabled => _mascotEnabled;`
   - In `_init()`:
     ```dart
     _mascotEnabled = _prefs.getBool('mascotEnabled') ?? true;
     ```
   - Add setter:
     ```dart
     Future<void> setMascotEnabled(bool value) async {
       if (!_isInitialized) return;
       _mascotEnabled = value;
       await _prefs.setBool('mascotEnabled', value);
       notifyListeners();
     }
     ```
2. In `sudoku_app/lib/screens/settings_screen.dart`:
   - Add a settings switch tile under the game options:
     ```dart
     _buildSwitchTile(
       context,
       icon: Icons.face_rounded,
       title: 'Sudoku Mascot',
       subtitle: 'Show animated mascot companion during gameplay',
       value: settings.mascotEnabled,
       onChanged: (val) => settings.setMascotEnabled(val),
     ),
     ```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/settings_mascot_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/core/settings_controller.dart sudoku_app/lib/screens/settings_screen.dart sudoku_app/test/settings_mascot_test.dart
git commit -m "feat(settings): add mascot enabled toggle to settings and controller"
```

---

---

### Task 7: Sound-Synchronized Mascot Audio System

**Files:**
- Modify: `sudoku_app/lib/core/audio_controller.dart`
- Test: `sudoku_app/test/mascot_audio_test.dart`

**Interfaces:**
- Consumes: `just_audio`, `HapticFeedback`, existing audio assets
- Produces:
  - `Future<void> playMascotEntrance()`: Plays whoosh/glide sound with light haptic flutter
  - `Future<void> playMascotLanding()`: Plays cheerful landing sound/click
  - `Future<void> playMascotTap()`: Plays playful chirp/hop sound with light impact
  - `Future<void> playMascotEncourage()`: Plays encouraging chime
  - `Future<void> playMascotStreak()`: Plays celebratory streak chime

- [ ] **Step 1: Write the failing mascot audio test**

```dart
// sudoku_app/test/mascot_audio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/core/audio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'sound_enabled': true});
  });

  test('AudioController exposes mascot audio hooks without errors', () async {
    final audio = AudioController.instance;
    expect(audio.isSoundEnabled, isTrue);

    // Verify hooks can be called safely
    await audio.playMascotEntrance();
    await audio.playMascotLanding();
    await audio.playMascotTap();
    await audio.playMascotEncourage();
    await audio.playMascotStreak();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/mascot_audio_test.dart`
Expected: FAIL with "The method 'playMascotEntrance' isn't defined for the class 'AudioController'"

- [ ] **Step 3: Implement mascot audio hooks in AudioController**

In `sudoku_app/lib/core/audio_controller.dart`:
```dart
  Future<void> playMascotEntrance() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.selectionClick();
    await _placePlayer.seek(Duration.zero);
    await _placePlayer.play();
  }

  Future<void> playMascotLanding() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.lightImpact();
    await _clickPlayer.seek(Duration.zero);
    await _clickPlayer.play();
  }

  Future<void> playMascotTap() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.mediumImpact();
    await _clickPlayer.seek(Duration.zero);
    await _clickPlayer.play();
  }

  Future<void> playMascotEncourage() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.lightImpact();
    await _placePlayer.seek(Duration.zero);
    await _placePlayer.play();
  }

  Future<void> playMascotStreak() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.heavyImpact();
    await _victoryPlayer.seek(Duration.zero);
    await _victoryPlayer.play();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/mascot_audio_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/core/audio_controller.dart sudoku_app/test/mascot_audio_test.dart
git commit -m "feat(audio): add sound-synchronized audio hooks for mascot buddy"
```

---

### Task 8: Flying Entrance Swoop Animation Widget (`FlyingMascotEntrance`)

**Files:**
- Create: `sudoku_app/lib/widgets/flying_mascot_entrance.dart`
- Test: `sudoku_app/test/flying_mascot_entrance_test.dart`

**Interfaces:**
- Consumes: Flutter native animation (`AnimationController`, `CurvedAnimation`, `Transform`), `AudioController`
- Produces:
  - `class FlyingMascotEntrance extends StatefulWidget`
    - `final Widget child`
    - `final VoidCallback? onLanded`
    - `final bool autoStart`
    - `final Duration duration`

**Animation Physics:**
- Starts offscreen top-right (dx: 120, dy: -220).
- Swoops along a curved path using `Curves.easeOutCubic` to final resting position (0, 0).
- Includes micro wing-flutter oscillation: `sin(t * 6 * pi) * 0.08` rotation for natural aerodynamic flutter.
- Ends with an organic landing squash-and-stretch settle (`Curves.elasticOut`).
- Sound-synced: Triggers `playMascotEntrance()` at t=0 and `playMascotLanding()` when arriving at resting position.
- Tap-to-skip: Tapping anywhere during flight instantly settles the mascot at perch to ensure zero friction for speed players.

- [ ] **Step 1: Write the failing FlyingMascotEntrance widget test**

```dart
// sudoku_app/test/flying_mascot_entrance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/widgets/flying_mascot_entrance.dart';

void main() {
  testWidgets('FlyingMascotEntrance renders child and triggers onLanded callback', (tester) async {
    bool landed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlyingMascotEntrance(
            duration: const Duration(milliseconds: 300),
            onLanded: () => landed = true,
            child: const Text('Mascot Child'),
          ),
        ),
      ),
    );

    expect(find.text('Mascot Child'), findsOneWidget);
    expect(landed, isFalse);

    await tester.pump(const Duration(milliseconds: 350));
    expect(landed, isTrue);
  });

  testWidgets('FlyingMascotEntrance tap instantly completes flight', (tester) async {
    bool landed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlyingMascotEntrance(
            duration: const Duration(milliseconds: 1000),
            onLanded: () => landed = true,
            child: const Text('Mascot Child'),
          ),
        ),
      ),
    );

    // Tap to skip
    await tester.tap(find.byType(FlyingMascotEntrance));
    await tester.pump();
    expect(landed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/flying_mascot_entrance_test.dart`
Expected: FAIL with compilation error "Cannot find 'package:sudoku_app/widgets/flying_mascot_entrance.dart'"

- [ ] **Step 3: Implement FlyingMascotEntrance**

```dart
// sudoku_app/lib/widgets/flying_mascot_entrance.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/audio_controller.dart';

class FlyingMascotEntrance extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLanded;
  final bool autoStart;
  final Duration duration;

  const FlyingMascotEntrance({
    super.key,
    required this.child,
    this.onLanded,
    this.autoStart = true,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<FlyingMascotEntrance> createState() => _FlyingMascotEntranceState();
}

class _FlyingMascotEntranceState extends State<FlyingMascotEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flightCurve;
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _flightCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        AudioController.instance.playMascotLanding();
        widget.onLanded?.call();
      }
    });

    if (widget.autoStart) {
      _startFlight();
    }
  }

  void _startFlight() {
    if (!_soundPlayed) {
      _soundPlayed = true;
      AudioController.instance.playMascotEntrance();
    }
    _controller.forward();
  }

  void _skipFlight() {
    if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
      AudioController.instance.playMascotLanding();
      widget.onLanded?.call();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skipFlight,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _flightCurve,
        builder: (context, child) {
          final progress = _flightCurve.value;

          // Flight trajectory: swoop down from top-right (+120, -180) to (0, 0)
          final dx = (1.0 - progress) * 120.0;
          final dy = (1.0 - progress) * -180.0;

          // Flutter rotation: oscillate wings during flight
          final flutter = progress < 0.95
              ? math.sin(progress * 6 * math.pi) * 0.08 * (1.0 - progress)
              : 0.0;

          // Dynamic scale: start slightly smaller (0.7) and settle to 1.0
          final scale = 0.7 + (progress * 0.3);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: flutter,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/flying_mascot_entrance_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/widgets/flying_mascot_entrance.dart sudoku_app/test/flying_mascot_entrance_test.dart
git commit -m "feat(mascot): add sound-synced FlyingMascotEntrance swoop animation"
```

---

### Task 9: Prominent Buddy Companion Perch & Speech Bubble System

**Files:**
- Create: `sudoku_app/lib/widgets/mascot_speech_bubble.dart`
- Create: `sudoku_app/lib/widgets/mascot_buddy_perch.dart`
- Test: `sudoku_app/test/mascot_speech_bubble_test.dart`
- Test: `sudoku_app/test/mascot_buddy_perch_test.dart`

**UX & Buddy Psychology:**
- Mascots in top casual games (Duolingo, Animal Crossing) act as **empathetic companions**, not punitive error judges.
- When player makes a mistake: Buddy tilts head empathetically and says: *"Oops! Take your time, you'll crack it!"* rather than displaying a stark red violation.
- When player makes a correct move / combo: Buddy bounces excitedly with cheerful chime and says: *"Sharp eye! ✨"* or *"Streak x3! On fire! 🔥"*.
- When player is inactive for 25s: Mascot perks up: *"Need a hint? Tap the magic wand!"*.
- Tapping mascot: Mascot hops with a happy hop animation, plays a joyful chirp sound, and says cute buddy lines (*"I'm cheering for you!"*, *"You got this!"*).

- [ ] **Step 1: Write the failing MascotSpeechBubble widget test**

```dart
// sudoku_app/test/mascot_speech_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/widgets/mascot_speech_bubble.dart';

void main() {
  testWidgets('MascotSpeechBubble displays text with animated opacity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MascotSpeechBubble(
            text: 'You got this!',
            visible: true,
          ),
        ),
      ),
    );

    expect(find.text('You got this!'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/mascot_speech_bubble_test.dart`
Expected: FAIL with compilation error

- [ ] **Step 3: Implement MascotSpeechBubble and MascotBuddyPerch**

`sudoku_app/lib/widgets/mascot_speech_bubble.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';

class MascotSpeechBubble extends StatelessWidget {
  final String text;
  final bool visible;
  final VoidCallback? onTap;

  const MascotSpeechBubble({
    super.key,
    required this.text,
    this.visible = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1.0 : 0.0,
      curve: Curves.easeOut,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: visible ? 1.0 : 0.8,
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2D3D) : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppColors.primaryLight.withOpacity(0.2),
                width: 1.2,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`sudoku_app/lib/widgets/mascot_buddy_perch.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/audio_controller.dart';
import '../core/mascot_controller.dart';
import 'mascot_speech_bubble.dart';
import 'mascot_widget.dart';

class MascotBuddyPerch extends StatefulWidget {
  final MascotController controller;
  final double size;

  const MascotBuddyPerch({
    super.key,
    required this.controller,
    this.size = 56,
  });

  @override
  State<MascotBuddyPerch> createState() => _MascotBuddyPerchState();
}

class _MascotBuddyPerchState extends State<MascotBuddyPerch>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  String _speechText = "Let's solve this!";
  bool _speechVisible = true;
  Timer? _speechTimer;
  int _tapIndex = 0;

  static const List<String> _tapQuotes = [
    "I'm cheering for you!",
    "Take your time, buddy!",
    "Look for rows with 8 numbers!",
    "You've got a sharp mind!",
    "High five! ✋",
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -12.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -12.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);

    // Dismiss initial greeting after 3 seconds
    _speechTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _speechVisible = false);
    });

    widget.controller.addListener(_onMascotChanged);
  }

  @override
  void dispose() {
    _speechTimer?.cancel();
    _bounceController.dispose();
    widget.controller.removeListener(_onMascotChanged);
    super.dispose();
  }

  void _onMascotChanged() {
    final mood = widget.controller.mood;
    switch (mood) {
      case MascotMood.happy:
        _showBubble("Brilliant move! ✨", duration: 2000);
        AudioController.instance.playMascotEncourage();
        break;
      case MascotMood.mistake:
        _showBubble("Oops! Let's rethink that one.", duration: 2400);
        break;
      case MascotMood.hint:
        _showBubble("Here's a clue for you! 💡", duration: 2400);
        break;
      case MascotMood.win:
        _showBubble("VICTORY! We did it! 🎉", duration: 5000);
        AudioController.instance.playMascotStreak();
        break;
      default:
        break;
    }
  }

  void _showBubble(String message, {int duration = 2200}) {
    _speechTimer?.cancel();
    if (mounted) {
      setState(() {
        _speechText = message;
        _speechVisible = true;
      });
      _speechTimer = Timer(Duration(milliseconds: duration), () {
        if (mounted) setState(() => _speechVisible = false);
      });
    }
  }

  void _handleTap() {
    AudioController.instance.playMascotTap();
    _bounceController.forward(from: 0.0);
    widget.controller.setMood(MascotMood.happy, duration: const Duration(milliseconds: 1400));
    _showBubble(_tapQuotes[_tapIndex % _tapQuotes.length]);
    _tapIndex++;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MascotSpeechBubble(
          text: _speechText,
          visible: _speechVisible,
          onTap: () => setState(() => _speechVisible = false),
        ),
        SizedBox(height: 4.h),
        AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: child,
            );
          },
          child: GestureDetector(
            onTap: _handleTap,
            child: MascotWidget(
              controller: widget.controller,
              size: widget.size,
              enableBreathing: true,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sudoku_app && dart test test/mascot_speech_bubble_test.dart test/mascot_buddy_perch_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/widgets/mascot_speech_bubble.dart sudoku_app/lib/widgets/mascot_buddy_perch.dart sudoku_app/test/mascot_speech_bubble_test.dart
git commit -m "feat(mascot): add prominent MascotBuddyPerch and animated MascotSpeechBubble"
```

---

### Task 10: Connect Mascot Buddy and Flying Entrance to GameScreen

**Files:**
- Modify: `sudoku_app/lib/screens/game_screen.dart`
- Test: `sudoku_app/test/game_screen_buddy_test.dart`

**Changes in GameScreen:**
1. In `_buildStatusLine`:
   - Replace the cramped 36px icon in the stats row with the flying-entrance wrapped `MascotBuddyPerch` (54px size).
   - Position it gracefully with breathing space between the status indicators and the Sudoku board.
2. In `GameController` listener:
   - Track consecutive correct entries (combo streak counter).
   - At 3 consecutive correct moves, trigger celebration audio and mascot streak celebration.
3. In `initState`:
   - Initialize `FlyingMascotEntrance` so the owl swoops into the game screen when gameplay begins.
   - Synchronize with entrance audio.

- [ ] **Step 1: Write the failing GameScreen buddy integration test**

```dart
// sudoku_app/test/game_screen_buddy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/core/sudoku_generator.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/widgets/mascot_buddy_perch.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'mascotEnabled': true, 'sound_enabled': true});
  });

  testWidgets('GameScreen mounts MascotBuddyPerch when mascotEnabled is true', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, _) => const MaterialApp(
          home: GameScreen(
            difficulty: Difficulty.easy,
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(MascotBuddyPerch), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sudoku_app && dart test test/game_screen_buddy_test.dart`
Expected: FAIL

- [ ] **Step 3: Update GameScreen with FlyingMascotEntrance and MascotBuddyPerch**

In `sudoku_app/lib/screens/game_screen.dart`:
- Import `../widgets/flying_mascot_entrance.dart` and `../widgets/mascot_buddy_perch.dart`.
- In `_buildStatusLine`, place `MascotBuddyPerch` inside `FlyingMascotEntrance`:
```dart
FlyingMascotEntrance(
  child: MascotBuddyPerch(
    controller: _mascotController,
    size: 50,
  ),
)
```
- Ensure stats row layout remains balanced and responsive across all device sizes without layout overflow.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sudoku_app && dart test test/game_screen_buddy_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add sudoku_app/lib/screens/game_screen.dart sudoku_app/test/game_screen_buddy_test.dart
git commit -m "feat(mascot): integrate FlyingMascotEntrance and MascotBuddyPerch into GameScreen"
```

---

### Task 11: Settings Option & Skip Toggles Verification

**Files:**
- Modify/Verify: `sudoku_app/lib/screens/settings_screen.dart`
- Test: `sudoku_app/test/settings_mascot_test.dart`

**Verification:**
- When `mascotEnabled == false`:
  - `MascotBuddyPerch` is completely hidden.
  - `FlyingMascotEntrance` does not play entrance sound or animate.
  - Game screen status row automatically collapses cleanly to full width.
- When `sound_enabled == false`:
  - Mascot animations continue visually with 60 FPS smoothness, while all audio hooks stay silent.

- [ ] **Step 1: Run settings mascot test**

Run: `cd sudoku_app && dart test test/settings_mascot_test.dart`
Expected: PASS

- [ ] **Step 2: Commit**

```bash
git commit -m "test(settings): verify mascot enable/disable toggle across screens"
```

---

### Task 12: Visual & Responsive Verification on Android Emulator

**Files:**
- All tests in `sudoku_app/test/`
- Emulator testing on active running emulator (`emulator-5554`)

- [ ] **Step 1: Run complete test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run Flutter analyze**

Run: `flutter analyze`
Expected: 0 warnings, 0 errors.

- [ ] **Step 3: Hot reload app on emulator and capture verification screenshot**

Hot reload: Press `r` on the running `flutter run` task, navigate to GameScreen, and verify:
1. Owl swoops onto screen with sound and lands on perch.
2. Speech bubble greets player with *"Let's solve this!"*.
3. Tapping the owl triggers happy bounce + audio + encouraging quote.
4. Correct move triggers happy reaction and chime.
5. Mistake triggers sympathetic buddy reaction without harshness.
6. Victory screen shows win celebration mascot.
7. Capture screenshot artifact to confirm flawless visuals and zero layout overflow.

- [ ] **Step 4: Final commit**

```bash
git commit -m "chore(mascot): complete animated mascot buddy system with flying entrance and sound sync"
```
