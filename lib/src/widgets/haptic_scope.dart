import 'package:flutter/material.dart';
import '../haptic_engine.dart';
import '../haptic_pattern.dart';

/// Provides haptic configuration to descendant widgets via [InheritedWidget].
///
/// Wrap a subtree with [HapticScope] to configure the default haptic behavior
/// for all [HapticButton] and [HapticFeedbackWrapper] widgets within.
class HapticScope extends InheritedWidget {
  /// Whether haptics are enabled for this scope.
  final bool enabled;

  /// Default pattern to use when no specific pattern is provided.
  final HapticPattern defaultPattern;

  /// Intensity multiplier (0.0 to 1.0) applied to all haptics in this scope.
  final double intensityScale;

  const HapticScope({
    super.key,
    this.enabled = true,
    HapticPattern? defaultPattern,
    this.intensityScale = 1.0,
    required super.child,
  }) : defaultPattern = defaultPattern ??
            const HapticPattern(events: []);

  /// Finds the nearest [HapticScope] ancestor.
  static HapticScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HapticScope>();
  }

  /// Plays the given pattern respecting scope settings.
  Future<void> play(HapticPattern pattern) async {
    if (!enabled) return;
    await HapticEngine.instance.play(pattern);
  }

  @override
  bool updateShouldNotify(HapticScope oldWidget) {
    return enabled != oldWidget.enabled ||
        intensityScale != oldWidget.intensityScale;
  }
}
