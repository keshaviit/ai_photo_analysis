import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/settings_controller.dart';
import '../core/theme_controller.dart';
import '../core/audio_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController.instance;
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_settings.isInitialized) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(24.w),
                children: [
                  _buildSectionHeader(context, 'GAMEPLAY'),
                  _buildSettingRow(
                    context,
                    title: 'Sound Effects & Haptics',
                    subtitle: 'Play sounds when interacting with the game.',
                    value: AudioController.instance.isSoundEnabled,
                    onChanged: (val) {
                      AudioController.instance.setSoundEnabled(val);
                      AudioController.instance.playClick();
                      setState(() {});
                    },
                  ),
                  _buildSettingRow(
                    context,
                    title: 'Mistakes Limit (3 Mistakes)',
                    subtitle: 'Game over if you make 3 mistakes.',
                    value: _settings.mistakesLimitEnabled,
                    onChanged: (val) {
                      AudioController.instance.playClick();
                      _settings.setMistakesLimit(val);
                    },
                  ),
                  _buildSettingRow(
                    context,
                    title: 'Highlight Identical Numbers',
                    subtitle: 'Highlight numbers matching the selected cell.',
                    value: _settings.highlightIdenticalEnabled,
                    onChanged: (val) {
                      AudioController.instance.playClick();
                      _settings.setHighlightIdentical(val);
                    },
                  ),
                  _buildSettingRow(
                    context,
                    title: 'Sudoku Mascot',
                    subtitle: 'Show animated mascot companion during gameplay.',
                    value: _settings.mascotEnabled,
                    onChanged: (val) {
                      AudioController.instance.playClick();
                      _settings.setMascotEnabled(val);
                    },
                  ),
                  SizedBox(height: 32.h),
                  _buildSectionHeader(context, 'APPEARANCE'),
                  _buildSettingRow(
                    context,
                    title: 'Dark Mode',
                    subtitle: 'Switch between light and dark themes.',
                    value: _settings.isDarkMode,
                    onChanged: (val) {
                      AudioController.instance.playClick();
                      _settings.setDarkMode(val);
                      ThemeController.toggleTheme();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              AudioController.instance.playClick();
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary,
              size: 20.sp,
            ),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Text(
            'Settings',
            style: GoogleFonts.nunito(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          SizedBox(width: 40.w), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 12.sp,
          fontWeight: FontWeight.w800,
          color: context.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
