import 'package:flutter/material.dart';
import '../haptic_engine.dart';
import '../haptic_pattern.dart';
import '../haptic_preset.dart';

/// Wraps any widget to add haptic feedback on tap.
class HapticFeedbackWrapper extends StatelessWidget {
  /// The haptic pattern to play.
  final HapticPattern hapticPattern;

  /// The child widget.
  final Widget child;

  /// Optional callback on tap.
  final VoidCallback? onTap;

  /// Optional callback on long press.
  final VoidCallback? onLongPress;

  /// Haptic pattern for long press (optional).
  final HapticPattern? longPressPattern;

  const HapticFeedbackWrapper({
    super.key,
    required this.hapticPattern,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.longPressPattern,
  });

  /// Creates a wrapper with a named preset.
  HapticFeedbackWrapper.preset({
    super.key,
    required String preset,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.longPressPattern,
  }) : hapticPattern = HapticPreset.all[preset] ?? HapticPreset.buttonTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await HapticEngine.instance.play(hapticPattern);
        onTap?.call();
      },
      onLongPress: onLongPress == null && longPressPattern == null
          ? null
          : () async {
              if (longPressPattern != null) {
                await HapticEngine.instance.play(longPressPattern!);
              }
              onLongPress?.call();
            },
      child: child,
    );
  }
}
