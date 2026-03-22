import 'haptic_event.dart';
import 'haptic_parameter.dart';
import 'haptic_pattern.dart';

/// Built-in haptic presets providing rich feedback patterns.
///
/// Each preset is defined as an AHAP-compatible [HapticPattern] constant.
class HapticPreset {
  const HapticPreset._();

  /// "da-DUM" — light tap followed by a heavier confirmation tap.
  static final success = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.5, sharpness: 0.6),
      HapticEvent.transient(time: 0.15, intensity: 1.0, sharpness: 0.5),
    ],
  );

  /// Sharp double buzz — high sharpness error signal.
  static final error = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 1.0, sharpness: 1.0),
      HapticEvent.continuous(
          time: 0.05, duration: 0.1, intensity: 0.8, sharpness: 0.9),
      HapticEvent.transient(time: 0.2, intensity: 1.0, sharpness: 1.0),
    ],
  );

  /// Medium tap with a light lingering tail.
  static final warning = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.7, sharpness: 0.6),
      HapticEvent.continuous(
          time: 0.08, duration: 0.15, intensity: 0.3, sharpness: 0.4),
    ],
  );

  /// Light, crisp single tap.
  static final buttonTap = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.4, sharpness: 0.8),
    ],
  );

  /// Very light detent feel for selection changes.
  static final selectionChange = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.2, sharpness: 0.5),
    ],
  );

  /// Fireworks — 3-stage rising taps with a fading tail.
  static final celebration = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.4, sharpness: 0.7),
      HapticEvent.transient(time: 0.1, intensity: 0.6, sharpness: 0.8),
      HapticEvent.transient(time: 0.2, intensity: 1.0, sharpness: 0.9),
      HapticEvent.continuous(
          time: 0.3, duration: 0.5, intensity: 0.6, sharpness: 0.5),
    ],
    parameterCurves: [
      HapticParameterCurve(
        parameterId: HapticParameterId.hapticIntensityControl,
        time: 0.3,
        controlPoints: [
          HapticParameterControlPoint(time: 0.0, value: 0.6),
          HapticParameterControlPoint(time: 0.25, value: 0.3),
          HapticParameterControlPoint(time: 0.5, value: 0.0),
        ],
      ),
    ],
  );

  /// Drum roll → thud — 5 escalating transients + continuous + final thud.
  static final streakMilestone = HapticPattern(
    events: [
      HapticEvent.transient(time: 0.0, intensity: 0.3, sharpness: 0.7),
      HapticEvent.transient(time: 0.06, intensity: 0.4, sharpness: 0.7),
      HapticEvent.transient(time: 0.12, intensity: 0.5, sharpness: 0.7),
      HapticEvent.transient(time: 0.18, intensity: 0.7, sharpness: 0.7),
      HapticEvent.transient(time: 0.24, intensity: 0.9, sharpness: 0.7),
      HapticEvent.continuous(
          time: 0.3, duration: 0.2, intensity: 0.8, sharpness: 0.5),
      HapticEvent.transient(time: 0.55, intensity: 1.0, sharpness: 0.3),
    ],
  );

  /// Power-up — rising rumble → pop with trailing buzz.
  static final levelUp = HapticPattern(
    events: [
      HapticEvent.continuous(
          time: 0.0, duration: 0.4, intensity: 0.5, sharpness: 0.3),
      HapticEvent.transient(time: 0.35, intensity: 0.7, sharpness: 0.8),
      HapticEvent.transient(time: 0.45, intensity: 1.0, sharpness: 1.0),
      HapticEvent.continuous(
          time: 0.5, duration: 0.3, intensity: 0.3, sharpness: 0.6),
    ],
    parameterCurves: [
      HapticParameterCurve(
        parameterId: HapticParameterId.hapticIntensityControl,
        time: 0.0,
        controlPoints: [
          HapticParameterControlPoint(time: 0.0, value: 0.2),
          HapticParameterControlPoint(time: 0.2, value: 0.5),
          HapticParameterControlPoint(time: 0.4, value: 1.0),
        ],
      ),
      HapticParameterCurve(
        parameterId: HapticParameterId.hapticSharpnessControl,
        time: 0.0,
        controlPoints: [
          HapticParameterControlPoint(time: 0.0, value: 0.2),
          HapticParameterControlPoint(time: 0.4, value: 0.8),
        ],
      ),
    ],
  );

  /// All available presets as a map.
  static final Map<String, HapticPattern> all = {
    'success': success,
    'error': error,
    'warning': warning,
    'buttonTap': buttonTap,
    'selectionChange': selectionChange,
    'celebration': celebration,
    'streakMilestone': streakMilestone,
    'levelUp': levelUp,
  };
}
