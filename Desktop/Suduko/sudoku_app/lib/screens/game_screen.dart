import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/audio_controller.dart';
import '../core/game_controller.dart';
import '../core/sudoku_generator.dart';
import '../core/mascot_controller.dart';
import '../widgets/flying_mascot_entrance.dart';
import '../widgets/mascot_buddy_perch.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/streak_celebration_overlay.dart';
import '../ads/rewarded_ad_service.dart';
import '../ads/interstitial_ad_service.dart';

import 'package:confetti/confetti.dart';

class GameScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final bool isDaily;
  final bool isResume;

  const GameScreen({
    super.key,
    required this.difficulty,
    this.isDaily = false,
    this.isResume = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameController _controller;
  late MascotController _mascotController;
  bool _isShowingAd = false;
  late ConfettiController _confettiController;
  bool _hasPlayedConfetti = false;
  int _prevMistakes = 0;
  int? _prevFilledCount;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _mascotController = MascotController();
    _controller = GameController(
      widget.difficulty,
      isDaily: widget.isDaily,
      isResume: widget.isResume,
    );
    _controller.addListener(_onGameStateChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    _mascotController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_controller.isPaused &&
          !_controller.isGameWon &&
          !_controller.isGameOver &&
          !_isShowingAd) {
        _controller.togglePause();
      }
    }
  }

  void _onGameStateChanged() {
    if (_controller.isGameWon && !_hasPlayedConfetti) {
      _hasPlayedConfetti = true;
      _confettiController.play();
      _mascotController.onGameWon();
    } else if (_controller.isGameOver) {
      _mascotController.onGameOver();
    } else if (_controller.wrongInputCell != null) {
      if (_controller.mistakes > _prevMistakes) {
        _mascotController.onMistake();
        AudioController.instance.playMascotBubble();
        _prevMistakes = _controller.mistakes;
      }
    } else {
      // Count correctly filled cells to detect a correct move
      int filled = 0;
      if (!_controller.isLoading) {
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            final v = _controller.currentGrid[r][c];
            if (v != 0 && v == _controller.solutionGrid[r][c]) filled++;
          }
        }
      }
      if (_prevFilledCount == null) {
        _prevFilledCount = filled;
      } else if (filled > _prevFilledCount!) {
        _prevFilledCount = filled;
        _mascotController.onCorrectMove();
        if (_mascotController.streak == 3) {
          AudioController.instance.playMascotStreak();
        } else {
          AudioController.instance.playMascotBubble();
        }
      } else {
        _mascotController.onCellSelected(_controller.selectedCell != null);
      }
    }
    setState(() {});
  }

  void _handleHint() {
    if (_controller.hints <= 0) {
      if (RewardedAdService.instance.isAdAvailable) {
        _isShowingAd = true;
        RewardedAdService.instance.showAd(
          onRewardEarned: () {
            _controller.addHint();
            _controller.useHint();
            _mascotController.onHintUsed();
            AudioController.instance.playMascotBubble();
          },
          onAdDismissed: () {
            _isShowingAd = false;
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ads available right now. Try again later.'),
          ),
        );
      }
    } else {
      _controller.useHint();
      _mascotController.onHintUsed();
      AudioController.instance.playMascotBubble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: _controller.isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : FlyingMascotEntrance(
                controller: _mascotController,
                child: Stack(
                  children: [
                    // Main Game UI
                    IgnorePointer(
                      ignoring:
                          _controller.isPaused ||
                          _controller.isGameWon ||
                          _controller.isGameOver,
                      child: Column(
                        children: [
                          _buildTopBar(context),
                          _buildStatusLine(context),
                          _buildMascotPerch(context),
                          const Spacer(),
                          _buildSudokuGrid(context),
                          const Spacer(),
                          _buildActionBar(context),
                          SizedBox(height: 12.h),
                          _buildNumberPad(context),
                          SizedBox(height: 12.h),
                        ],
                      ),
                    ),

                    // Pause Overlay
                    if (_controller.isPaused &&
                        !_controller.isGameWon &&
                        !_controller.isGameOver)
                      _buildPauseOverlay(context),

                    // Victory Overlay
                    if (_controller.isGameWon)
                      widget.isDaily
                          ? StreakCelebrationOverlay(
                              onDismiss: () {
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            )
                          : _buildVictoryOverlay(context),

                    // Game Over Overlay
                    if (_controller.isGameOver) _buildGameOverOverlay(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    String diffText = widget.difficulty
        .toString()
        .split('.')
        .last
        .toUpperCase();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp),
            color: context.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            diffText,
            style: GoogleFonts.nunito(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: context.textSecondary,
            ),
          ),
          Text(
            _controller.formattedTime,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: context.textPrimary,
            ),
          ),
          IconButton(
            icon: Icon(
              _controller.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 28.sp,
            ),
            color: context.textSecondary,
            onPressed: _controller.togglePause,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Mistakes: ',
                style: GoogleFonts.nunito(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
              Text(
                '${_controller.mistakes}/3',
                style: GoogleFonts.nunito(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: _controller.mistakes > 0
                      ? AppColors.error
                      : context.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMascotPerch(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 4.h),
      child: MascotBuddyPerch(controller: _mascotController),
    );
  }

  Widget _buildSudokuGrid(BuildContext context) {
    final isDark = context.isDarkMode;
    final thickBorderColor = isDark
        ? const Color(0xFF555555)
        : const Color(0xFFA0A0B8);
    final thinBorderColor = isDark
        ? const Color(0xFF2E2E50)
        : const Color(0xFFDEDEE8);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: thickBorderColor, width: 2.0),
              ),
              child: Column(
                children: List.generate(9, (row) {
                  return Expanded(
                    child: Row(
                      children: List.generate(9, (col) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _controller.selectCell(row, col),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: row == 8
                                      ? BorderSide.none
                                      : BorderSide(
                                          color: (row == 2 || row == 5)
                                              ? thickBorderColor
                                              : thinBorderColor,
                                          width: (row == 2 || row == 5)
                                              ? 2.0
                                              : 0.5,
                                        ),
                                  right: col == 8
                                      ? BorderSide.none
                                      : BorderSide(
                                          color: (col == 2 || col == 5)
                                              ? thickBorderColor
                                              : thinBorderColor,
                                          width: (col == 2 || col == 5)
                                              ? 2.0
                                              : 0.5,
                                        ),
                                ),
                              ),
                              child: _buildCellContent(context, row, col),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(BuildContext context, int row, int col) {
    int val = _controller.currentGrid[row][col];
    bool isGiven = _controller.initialCells[row][col];
    bool isSelected =
        _controller.selectedCell?.row == row &&
        _controller.selectedCell?.col == col;

    // Check if error
    bool isError =
        !isGiven && val != 0 && val != _controller.solutionGrid[row][col];

    // Selected number tracking for highlighting
    int? selectedValue;
    if (_controller.selectedCell != null) {
      selectedValue =
          _controller.currentGrid[_controller.selectedCell!.row][_controller
              .selectedCell!
              .col];
    }

    bool isSameNumber = val != 0 && val == selectedValue && !isSelected;
    bool isRelated = false;

    if (!isSelected && !isSameNumber && _controller.selectedCell != null) {
      int sRow = _controller.selectedCell!.row;
      int sCol = _controller.selectedCell!.col;
      int sBoxR = sRow - sRow % 3;
      int sBoxC = sCol - sCol % 3;
      int boxR = row - row % 3;
      int boxC = col - col % 3;

      if (sRow == row || sCol == col || (sBoxR == boxR && sBoxC == boxC)) {
        isRelated = true;
      }
    }

    // Determine background color
    Color bgColor = Colors.transparent;
    bool isAnimatingWrong =
        _controller.wrongInputCell?.row == row &&
        _controller.wrongInputCell?.col == col;

    if (isSelected) {
      bgColor = AppColors.primary.withValues(alpha: 0.2);
    } else if (isError) {
      bgColor = AppColors.error.withValues(alpha: 0.15);
    } else if (isSameNumber) {
      bgColor = context.isDarkMode
          ? const Color(0xFF232326)
          : const Color(0xFFE2E2F4);
    } else if (isRelated) {
      bgColor = context.isDarkMode
          ? const Color(0xFF1C1C1C)
          : const Color(0xFFEAEAF5);
    }

    // Determine text color
    Color textColor = context.textPrimary;
    if (isError) {
      textColor = AppColors.error;
    } else if (!isGiven && val != 0) {
      textColor = AppColors.primary;
    }

    // Determine border overlay
    Border? overlayBorder;
    if (isSelected) {
      overlayBorder = Border.all(color: AppColors.primary, width: 2.0);
    } else if (isError) {
      overlayBorder = Border.all(color: AppColors.error, width: 1.5);
    } else if (isSameNumber) {
      overlayBorder = Border.all(
        color: AppColors.primary.withValues(alpha: 0.3),
        width: 1.0,
      );
    }

    Widget child;
    if (isAnimatingWrong) {
      child = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, _) {
          double scale = value < 0.5
              ? 1.0 + (value * 0.4)
              : 1.2 - ((value - 0.5) * 2.4);
          double opacity = value < 0.5 ? 1.0 : 1.0 - ((value - 0.5) * 2.0);
          return Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(2.w),
                  child: Text(
                    '${_controller.wrongInputValue}',
                    style: GoogleFonts.nunito(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (val != 0) {
      child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(2.w),
          child: Text(
            '$val',
            style: GoogleFonts.nunito(
              fontSize: 22.sp,
              fontWeight: isGiven ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      );
    } else if (_controller.notesGrid[row][col].isNotEmpty) {
      child = _buildNotesGrid(context, _controller.notesGrid[row][col]);
    } else {
      child = const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(color: bgColor, border: overlayBorder),
      child: Center(child: child),
    );
  }

  Widget _buildNotesGrid(BuildContext context, Set<int> notes) {
    return Padding(
      padding: EdgeInsets.all(2.0.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (r) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (c) {
              int num = r * 3 + c + 1;
              return Text(
                notes.contains(num) ? '$num' : '',
                style: GoogleFonts.nunito(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                  height: 1.0,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context,
            icon: Icons.undo_rounded,
            label: 'Undo',
            onTap: _controller.undo,
          ),
          _buildActionButton(
            context,
            icon: Icons.redo_rounded,
            label: 'Redo',
            onTap: _controller.redo,
          ),
          _buildActionButton(
            context,
            icon: Icons.backspace_outlined,
            label: 'Erase',
            onTap: _controller.erase,
          ),
          _buildActionButton(
            context,
            icon: Icons.edit_rounded,
            label: 'Notes',
            isActive: _controller.isNotesMode,
            onTap: _controller.toggleNotesMode,
            badge: _controller.isNotesMode ? 'ON' : 'OFF',
          ),
          _buildActionButton(
            context,
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            onTap: _handleHint,
            badgeWidget: _controller.hints <= 0
                ? Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 8.sp,
                          color: Colors.white,
                        ),
                        Text(
                          'AD',
                          style: GoogleFonts.nunito(
                            fontSize: 7.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            badge: _controller.hints > 0 ? '${_controller.hints}' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    String? badge,
    Widget? badgeWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58.w,
        height: 52.w,
        decoration: BoxDecoration(
          color: isActive ? context.surface2Color : context.surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : context.borderColor,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20.sp,
                  color: isActive ? AppColors.primary : context.textPrimary,
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.primary : context.textSecondary,
                  ),
                ),
              ],
            ),
            if (badgeWidget != null)
              Positioned(top: -6, right: -6, child: badgeWidget)
            else if (badge != null)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : context.surface2Color,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: isActive ? AppColors.primary : context.borderColor,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.nunito(
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w900,
                      color: isActive ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(BuildContext context) {
    int? selectedValue;
    if (_controller.selectedCell != null) {
      selectedValue =
          _controller.currentGrid[_controller.selectedCell!.row][_controller
              .selectedCell!
              .col];
    }

    // Precalculate counts to grey out completed numbers
    Map<int, int> counts = {for (var i = 1; i <= 9; i++) i: 0};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        int v = _controller.currentGrid[r][c];
        if (v != 0 && v == _controller.solutionGrid[r][c]) {
          counts[v] = counts[v]! + 1;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(9, (index) {
          int num = index + 1;
          bool isCompleted = counts[num] == 9;
          bool isSelected = num == selectedValue;

          return GestureDetector(
            onTap: isCompleted ? null : () => _controller.inputNumber(num),
            child: Container(
              width: 32.w, // Adjusted for typical mobile width (9 * 32 = 288)
              height: 48.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isCompleted
                          ? context.surface2Color.withValues(alpha: 0.5)
                          : context.surfaceColor),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isCompleted
                            ? context.borderColor.withValues(alpha: 0.5)
                            : context.borderColor),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$num',
                style: GoogleFonts.nunito(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isCompleted
                            ? context.textSecondary.withValues(alpha: 0.5)
                            : context.textPrimary),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPauseOverlay(BuildContext context) {
    return GestureDetector(
      onTap: _controller.togglePause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: context.isDarkMode ? 0.65 : 0.45),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: Center(
            child: GestureDetector(
              onTap:
                  () {}, // Prevent taps on modal from bubbling up and unpausing
              child: Container(
                width: 296.w,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border.all(color: context.borderColor),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PAUSED',
                      style: GoogleFonts.nunito(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: context.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _controller.formattedTime,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Column(
                      children: [
                        _buildPauseButton(
                          label: 'RESUME GAME',
                          icon: Icons.play_arrow_rounded,
                          isPrimary: true,
                          onTap: _controller.togglePause,
                        ),
                        SizedBox(height: 10.h),
                        _buildPauseButton(
                          label: 'Restart',
                          icon: Icons.refresh_rounded,
                          onTap: _showRestartConfirmation,
                        ),
                        SizedBox(height: 10.h),
                        _buildPauseButton(
                          label: 'New Game',
                          icon: Icons.add_rounded,
                          onTap: _showNewGameConfirmation,
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Tap outside anywhere to resume',
                      style: GoogleFonts.nunito(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
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
  }

  Widget _buildPauseButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48.w,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : context.surface2Color,
          borderRadius: BorderRadius.circular(12.r),
          border: isPrimary ? null : Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isPrimary ? Colors.white : context.textSecondary,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14.sp,
                fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: isPrimary ? 0.5 : 0,
                color: isPrimary ? Colors.white : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: Container(
            width: 296.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.error,
                    size: 20.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Start this puzzle over?',
                  style: GoogleFonts.nunito(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Your current progress will be lost.',
                  style: GoogleFonts.nunito(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // close dialog
                        _controller.restartCurrentGame();
                        if (_controller.isPaused) {
                          _controller.togglePause();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Restart',
                          style: GoogleFonts.nunito(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: context.surface2Color,
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.nunito(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNewGameConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: Container(
            width: 296.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start a new game?',
                  style: GoogleFonts.nunito(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Your current progress will be lost.',
                  style: GoogleFonts.nunito(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // close dialog
                        Navigator.pop(context); // go back to difficulty select
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'New Game',
                          style: GoogleFonts.nunito(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: context.surface2Color,
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.nunito(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalButton(
    BuildContext context,
    String text,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary
              : (context.isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.circular(12.r),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: isPrimary ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildVictoryOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: context.isDarkMode ? 0.65 : 0.45),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Container(
                width: 296.w,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border.all(color: context.borderColor),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MascotWidget(
                      staticMood: MascotMood.win,
                      size: 96,
                      enableBreathing: true,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Puzzle Solved!',
                      style: GoogleFonts.nunito(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Time',
                              style: GoogleFonts.nunito(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _controller.formattedTime,
                              style: GoogleFonts.nunito(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Mistakes',
                              style: GoogleFonts.nunito(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${_controller.mistakes}/3',
                              style: GoogleFonts.nunito(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 32.h),
                    _buildModalButton(context, 'New Game', () {
                      _isShowingAd = true;
                      InterstitialAdService.instance.showAdIfAppropriate(
                        onAdDismissed: () {
                          _isShowingAd = false;
                          if (mounted) Navigator.pop(context);
                        },
                      );
                    }, isPrimary: true),
                  ],
                ),
              ),
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: context.isDarkMode ? 0.65 : 0.45),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Center(
          child: Container(
            width: 296.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MascotWidget(
                  staticMood: MascotMood.mistake,
                  size: 80,
                  enableBreathing: false,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Game Over',
                  style: GoogleFonts.nunito(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'You made 3 mistakes.',
                  style: GoogleFonts.nunito(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(height: 32.h),
                if (RewardedAdService.instance.isAdAvailable) ...[
                  _buildModalButton(context, 'Watch Ad to Continue', () {
                    _isShowingAd = true;
                    RewardedAdService.instance.showAd(
                      onRewardEarned: () {
                        _controller.useLifeline();
                      },
                      onAdDismissed: () {
                        _isShowingAd = false;
                      },
                    );
                  }, isPrimary: true),
                  SizedBox(height: 12.h),
                ],
                _buildModalButton(context, 'Try Again', () {
                  Navigator.pop(context); // Go back to difficulty selection
                }, isPrimary: !RewardedAdService.instance.isAdAvailable),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
