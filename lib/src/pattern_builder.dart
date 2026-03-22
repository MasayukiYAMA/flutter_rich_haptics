import 'haptic_event.dart';
import 'haptic_parameter.dart';
import 'haptic_pattern.dart';

/// A fluent builder for constructing [HapticPattern]s programmatically.
///
/// ```dart
/// final pattern = PatternBuilder()
///   .addTransient(time: 0.0, intensity: 0.8, sharpness: 0.6)
///   .addContinuous(time: 0.1, duration: 0.3, intensity: 0.5)
///   .addIntensityCurve(time: 0.1, points: [(0.0, 0.5), (0.3, 1.0)])
///   .build();
/// ```
class PatternBuilder {
  final List<HapticEvent> _events = [];
  final List<HapticParameterCurve> _curves = [];

  /// Adds a transient (tap) event.
  PatternBuilder addTransient({
    required double time,
    double intensity = 1.0,
    double sharpness = 0.5,
  }) {
    _events.add(HapticEvent.transient(
      time: time,
      intensity: intensity,
      sharpness: sharpness,
    ));
    return this;
  }

  /// Adds a continuous (sustained vibration) event.
  PatternBuilder addContinuous({
    required double time,
    required double duration,
    double intensity = 1.0,
    double sharpness = 0.5,
  }) {
    _events.add(HapticEvent.continuous(
      time: time,
      duration: duration,
      intensity: intensity,
      sharpness: sharpness,
    ));
    return this;
  }

  /// Adds an arbitrary [HapticEvent].
  PatternBuilder addEvent(HapticEvent event) {
    _events.add(event);
    return this;
  }

  /// Adds an intensity control parameter curve.
  ///
  /// [points] is a list of (time, value) pairs relative to [time].
  PatternBuilder addIntensityCurve({
    required double time,
    required List<(double, double)> points,
  }) {
    _curves.add(HapticParameterCurve(
      parameterId: HapticParameterId.hapticIntensityControl,
      time: time,
      controlPoints: points
          .map((p) => HapticParameterControlPoint(time: p.$1, value: p.$2))
          .toList(),
    ));
    return this;
  }

  /// Adds a sharpness control parameter curve.
  ///
  /// [points] is a list of (time, value) pairs relative to [time].
  PatternBuilder addSharpnessCurve({
    required double time,
    required List<(double, double)> points,
  }) {
    _curves.add(HapticParameterCurve(
      parameterId: HapticParameterId.hapticSharpnessControl,
      time: time,
      controlPoints: points
          .map((p) => HapticParameterControlPoint(time: p.$1, value: p.$2))
          .toList(),
    ));
    return this;
  }

  /// Adds an arbitrary [HapticParameterCurve].
  PatternBuilder addParameterCurve(HapticParameterCurve curve) {
    _curves.add(curve);
    return this;
  }

  /// Builds and returns the [HapticPattern].
  HapticPattern build() {
    return HapticPattern(
      events: List.unmodifiable(_events),
      parameterCurves: List.unmodifiable(_curves),
    );
  }
}
