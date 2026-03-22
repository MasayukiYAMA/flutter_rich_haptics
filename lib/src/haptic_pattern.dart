import 'haptic_event.dart';
import 'haptic_parameter.dart';

/// A haptic pattern consisting of events and optional parameter curves.
///
/// This is the core data model representing an AHAP (Apple Haptic Audio Pattern)
/// that can be played on both iOS and Android.
class HapticPattern {
  /// The haptic events in this pattern.
  final List<HapticEvent> events;

  /// Optional parameter curves to modulate events over time.
  final List<HapticParameterCurve> parameterCurves;

  const HapticPattern({
    required this.events,
    this.parameterCurves = const [],
  });

  /// Converts this pattern to an AHAP JSON-compatible map.
  Map<String, dynamic> toAhapMap() {
    final pattern = <Map<String, dynamic>>[];

    for (final event in events) {
      pattern.add(event.toAhapMap());
    }

    for (final curve in parameterCurves) {
      pattern.add(curve.toAhapMap());
    }

    return {
      'Version': 1.0,
      'Metadata': {
        'Project': 'flutter_rich_haptics',
        'Created': 'FlutterRichHaptics',
      },
      'Pattern': pattern,
    };
  }

  /// Creates a [HapticPattern] from an AHAP JSON-compatible map.
  factory HapticPattern.fromAhapMap(Map<String, dynamic> map) {
    final pattern = map['Pattern'] as List<dynamic>;
    final events = <HapticEvent>[];
    final curves = <HapticParameterCurve>[];

    for (final element in pattern) {
      final el = element as Map<String, dynamic>;
      if (el.containsKey('Event')) {
        events.add(HapticEvent.fromAhapMap(el));
      } else if (el.containsKey('ParameterCurve')) {
        curves.add(HapticParameterCurve.fromAhapMap(el));
      }
    }

    return HapticPattern(events: events, parameterCurves: curves);
  }

  /// Total duration of the pattern in seconds.
  double get totalDuration {
    double maxEnd = 0.0;
    for (final event in events) {
      final end = event.time + event.duration;
      if (end > maxEnd) maxEnd = end;
    }
    for (final curve in parameterCurves) {
      for (final cp in curve.controlPoints) {
        final end = curve.time + cp.time;
        if (end > maxEnd) maxEnd = end;
      }
    }
    return maxEnd;
  }

  @override
  String toString() =>
      'HapticPattern(events: ${events.length}, curves: ${parameterCurves.length})';
}
