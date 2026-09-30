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
  }) : assert(
         controller != null || staticMood != null,
         'Either controller or staticMood must be provided',
       );

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
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
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
