import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/theme_controller.dart';
import '../core/sudoku_generator.dart';
import '../core/mascot_controller.dart';
import '../widgets/mascot_widget.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/stats_controller.dart';
import '../core/audio_controller.dart';
import 'game_screen.dart';
import 'daily_challenge_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasSavedGame = false;
  String _savedDifficulty = '';
  bool _savedIsDaily = false;
  int _savedTime = 0;
  double _savedProgress = 0.0;
  late MascotController _homeMascotController;

  @override
  void initState() {
    super.initState();
    _homeMascotController = MascotController();
    StatsController.instance.addListener(_onStatsChanged);
    _checkSavedGame();
  }

  @override
  void dispose() {
    StatsController.instance.removeListener(_onStatsChanged);
    _homeMascotController.dispose();
    super.dispose();
  }

  void _onStatsChanged() {
    setState(() {});
  }

  Future<void> _checkSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasSavedGame = prefs.getBool('has_saved_game') ?? false;
      if (_hasSavedGame) {
        _savedDifficulty = prefs.getString('saved_difficulty') ?? 'Medium';
        _savedIsDaily = prefs.getBool('saved_isDaily') ?? false;
        _savedTime = prefs.getInt('saved_elapsedSeconds') ?? 0;

        try {
          final gridStr = prefs.getString('saved_currentGrid');
          final initialStr = prefs.getString('saved_initialCells');
          if (gridStr != null && initialStr != null) {
            final List<dynamic> gridJson = jsonDecode(gridStr);
            final List<dynamic> initialJson = jsonDecode(initialStr);
            int totalEmpty = 0;
            int filled = 0;
            for (int r = 0; r < 9; r++) {
              for (int c = 0; c < 9; c++) {
                final isInitial = initialJson[r][c] as bool;
                if (!isInitial) {
                  totalEmpty++;
                  final val = gridJson[r][c] as int;
                  if (val != 0) {
                    filled++;
                  }
                }
              }
            }
            _savedProgress = totalEmpty > 0 ? (filled / totalEmpty) : 0.0;
          }
        } catch (e) {
          _savedProgress = 0.0;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0.w, vertical: 8.0.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar: Streak (Left) & Controls (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Streak Indicator
                  GestureDetector(
                    onTap: () {
                      AudioController.instance.playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyChallengeScreen(),
                        ),
                      ).then((_) => _checkSavedGame());
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 15.sp)),
                          SizedBox(width: 6.w),
                          Text(
                            '${StatsController.instance.currentWinStreak}',
                            style: GoogleFonts.nunito(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Controls: Theme Toggle & Settings
                  Row(
                    children: [
                      _buildIconButton(
                        context,
                        icon: isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        tooltip: isDark
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                        onTap: () {
                          AudioController.instance.playClick();
                          ThemeController.toggleTheme();
                        },
                      ),
                      SizedBox(width: 8.w),
                      _buildIconButton(
                        context,
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        onTap: () {
                          AudioController.instance.playClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Center Brand Graphic
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotWidget(
                    controller: _homeMascotController,
                    size: 80,
                    enableBreathing: true,
                    onTap: () {
                      AudioController.instance.playClick();
                      _homeMascotController.setMood(
                        MascotMood.happy,
                        duration: const Duration(milliseconds: 1500),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildHomeEmblem(context),
                  SizedBox(height: 16.h),
                  Text(
                    'SUDOKU',
                    style: GoogleFonts.nunito(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                      color: context.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'THINK. SOLVE. REPEAT.',
                    style: GoogleFonts.nunito(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                      color: context.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),

              // Bottom Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Continue Game Card
                  if (_hasSavedGame) ...[
                    InkWell(
                      onTap: () {
                        AudioController.instance.playClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameScreen(
                              difficulty: SudokuDifficulty.values.firstWhere(
                                (value) => value.name == _savedDifficulty,
                                orElse: () => SudokuDifficulty.medium,
                              ),
                              isDaily: _savedIsDaily,
                              isResume: true,
                            ),
                          ),
                        ).then((_) => _checkSavedGame());
                      },
                      borderRadius: BorderRadius.circular(18.r),
                      child: Ink(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CONTINUE GAME',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  '$_savedDifficulty · ${_formatTime(_savedTime)}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            // Progress Bar
                            Container(
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(3.r),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _savedProgress > 0
                                    ? _savedProgress
                                    : 0.05, // Show at least a tiny sliver if 0
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(3.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // New Game Button
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AudioController.instance.playClick();
                        Navigator.pushNamed(
                          context,
                          '/difficulty',
                        ).then((_) => _checkSavedGame());
                      },
                      icon: Icon(Icons.play_arrow_rounded, size: 22.sp),
                      label: Text(
                        'NEW GAME',
                        style: GoogleFonts.nunito(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Daily Challenge & Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryCard(
                          context,
                          icon: Icons.calendar_today_rounded,
                          label: 'DAILY CHALLENGE',
                          iconColor: AppColors.warning,
                          onTap: () {
                            AudioController.instance.playClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyChallengeScreen(),
                              ),
                            ).then((_) => _checkSavedGame());
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildSecondaryCard(
                          context,
                          icon: Icons.bar_chart_rounded,
                          label: 'STATS',
                          iconColor: AppColors.success,
                          onTap: () {
                            AudioController.instance.playClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: context.borderColor),
        ),
        child: Icon(icon, size: 20.sp, color: context.textSecondary),
      ),
    );
  }

  Widget _buildSecondaryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Ink(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: iconColor),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeEmblem(BuildContext context) {
    final isDark = context.isDarkMode;
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.2);

    return Container(
      width: 58.w,
      height: 58.w,
      padding: EdgeInsets.all(6.0.w),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.borderColor, width: 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniCell(context, '3'),
              _buildMiniDot(dotColor),
              _buildMiniCell(context, '9', isMuted: true),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniDot(dotColor),
              _buildMiniCell(context, '7', isAccent: true),
              _buildMiniDot(dotColor),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniCell(context, '4', isMuted: true),
              _buildMiniDot(dotColor),
              _buildMiniCell(context, '1'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCell(
    BuildContext context,
    String text, {
    bool isMuted = false,
    bool isAccent = false,
  }) {
    Color textColor = isAccent
        ? AppColors.primary
        : (isMuted ? context.textSecondary : context.textPrimary);

    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        color: isAccent
            ? AppColors.primary.withValues(alpha: 0.15)
            : context.surface2Color,
        borderRadius: BorderRadius.circular(3.r),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildMiniDot(Color dotColor) {
    return SizedBox(
      width: 12.w,
      height: 12.w,
      child: Center(
        child: Container(
          width: 2.5.w,
          height: 2.5.w,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
