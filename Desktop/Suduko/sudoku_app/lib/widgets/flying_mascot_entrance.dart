import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/audio_controller.dart';
import '../core/mascot_controller.dart';
import '../core/settings_controller.dart';
import 'mascot_widget.dart';

class FlyingMascotEntrance extends StatefulWidget {
  final MascotController controller;
  final Widget child;
  final Duration duration;
  final VoidCallback? onComplete;

  const FlyingMascotEntrance({
    super.key,
    required this.controller,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.onComplete,
  });

  @override
  State<FlyingMascotEntrance> createState() => _FlyingMascotEntranceState();
}

class _FlyingMascotEntranceState extends State<FlyingMascotEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flightProgress;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _flightProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishEntrance();
      }
    });

    if (SettingsController.instance.mascotEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AudioController.instance.playMascotEntrance();
        _controller.forward();
      });
    } else {
      _hasCompleted = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skipEntrance() {
    if (_hasCompleted) return;
    _controller.value = 1;
    _finishEntrance();
  }

  void _finishEntrance() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    AudioController.instance.playMascotLanding();
    widget.onComplete?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCompleted || !SettingsController.instance.mascotEnabled) {
      return widget.child;
    }

    final mediaSize = MediaQuery.sizeOf(context);
    final mascotSize = 62.w.clamp(52.0, 72.0);
    final start = Offset(mediaSize.width + mascotSize, -mascotSize * 1.4);
    final end = Offset(mediaSize.width - mascotSize - 26.w, 94.h);
    final control = Offset(mediaSize.width * 0.7, 18.h);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _skipEntrance,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _flightProgress.value.clamp(0.0, 1.0);
                  final position = _quadraticBezier(start, control, end, t);
                  final flutter = math.sin(t * 6 * math.pi) * 0.08;
                  final landing = t > 0.82
                      ? math.sin((t - 0.82) / 0.18 * math.pi)
                      : 0.0;

                  return Transform.translate(
                    offset: position,
                    child: Transform.rotate(
                      angle: -0.22 + (0.22 * t) + flutter,
                      child: Transform.scale(
                        scaleX: 1 + (landing * 0.08),
                        scaleY: 1 - (landing * 0.08),
                        child: child,
                      ),
                    ),
                  );
                },
                child: MascotWidget(
                  controller: widget.controller,
                  size: mascotSize,
                  enableBreathing: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _quadraticBezier(Offset start, Offset control, Offset end, double t) {
    final inverse = 1 - t;
    return (start * inverse * inverse) +
        (control * 2 * inverse * t) +
        (end * t * t);
  }
}
