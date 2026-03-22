import 'package:flutter/material.dart';
import '../haptic_engine.dart';
import '../haptic_pattern.dart';
import '../haptic_preset.dart';

/// A button that plays a haptic pattern when tapped.
///
/// Wraps a standard [ElevatedButton] with haptic feedback.
class HapticButton extends StatelessWidget {
  /// The haptic pattern to play on tap.
  final HapticPattern hapticPattern;

  /// The callback when the button is pressed.
  final VoidCallback? onPressed;

  /// The child widget.
  final Widget child;

  /// Button style.
  final ButtonStyle? style;

  const HapticButton({
    super.key,
    this.hapticPattern = const HapticPattern(events: []),
    this.onPressed,
    required this.child,
    this.style,
  });

  /// Creates a [HapticButton] with a preset haptic pattern.
  HapticButton.preset({
    super.key,
    required String preset,
    this.onPressed,
    required this.child,
    this.style,
  }) : hapticPattern = HapticPreset.all[preset] ?? HapticPreset.buttonTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: onPressed == null
          ? null
          : () async {
              await HapticEngine.instance.play(hapticPattern);
              onPressed?.call();
            },
      child: child,
    );
  }
}
