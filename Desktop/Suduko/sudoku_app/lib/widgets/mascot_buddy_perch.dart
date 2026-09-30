import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/audio_controller.dart';
import '../core/mascot_controller.dart';
import '../core/settings_controller.dart';
import 'mascot_widget.dart';

class MascotBuddyPerch extends StatefulWidget {
  final MascotController controller;

  const MascotBuddyPerch({super.key, required this.controller});

  @override
  State<MascotBuddyPerch> createState() => _MascotBuddyPerchState();
}

class _MascotBuddyPerchState extends State<MascotBuddyPerch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hopController;
  late final Animation<double> _hop;

  @override
  void initState() {
    super.initState();
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _hop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 45),
      TweenSequenceItem(tween: Tween(begin: -10, end: 0), weight: 55),
    ]).animate(CurvedAnimation(parent: _hopController, curve: Curves.easeOut));
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _hopController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleTap() {
    AudioController.instance.playMascotTap();
    widget.controller.onTapped();
    _hopController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!SettingsController.instance.mascotEnabled) {
      return const SizedBox.shrink();
    }

    final speech = widget.controller.speechText;

    return SizedBox(
      height: 82.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (speech != null)
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _MascotSpeechBubble(key: ValueKey(speech), text: speech),
              ),
            ),
          if (speech != null) const _BubbleTail(),
          SizedBox(width: 8.w),
          AnimatedBuilder(
            animation: _hop,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _hop.value),
                child: child,
              );
            },
            child: MascotWidget(
              controller: widget.controller,
              size: 58,
              onTap: _handleTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTail extends StatelessWidget {
  const _BubbleTail();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.78,
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(color: AppColors.primary.withValues(alpha: 0.22)),
            right: BorderSide(color: AppColors.primary.withValues(alpha: 0.22)),
          ),
        ),
      ),
    );
  }
}

class _MascotSpeechBubble extends StatelessWidget {
  final String text;

  const _MascotSpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }
}
