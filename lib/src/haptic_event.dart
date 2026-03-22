/// Type of haptic event in an AHAP pattern.
enum HapticEventType {
  /// A short, sharp tap-like haptic.
  hapticTransient,

  /// A sustained vibration over a duration.
  hapticContinuous,
}

/// A single haptic event within a [HapticPattern].
class HapticEvent {
  /// The type of haptic event.
  final HapticEventType eventType;

  /// When this event starts, in seconds from pattern start.
  final double time;

  /// Duration in seconds (only meaningful for [HapticEventType.hapticContinuous]).
  final double duration;

  /// Intensity of the haptic (0.0 to 1.0).
  final double intensity;

  /// Sharpness of the haptic (0.0 = dull/rumbly, 1.0 = sharp/crisp).
  final double sharpness;

  const HapticEvent({
    required this.eventType,
    required this.time,
    this.duration = 0.0,
    this.intensity = 1.0,
    this.sharpness = 0.5,
  })  : assert(intensity >= 0.0 && intensity <= 1.0),
        assert(sharpness >= 0.0 && sharpness <= 1.0),
        assert(time >= 0.0),
        assert(duration >= 0.0);

  /// Creates a transient (tap) event.
  const HapticEvent.transient({
    required this.time,
    this.intensity = 1.0,
    this.sharpness = 0.5,
  })  : eventType = HapticEventType.hapticTransient,
        duration = 0.0;

  /// Creates a continuous (sustained) event.
  const HapticEvent.continuous({
    required this.time,
    required this.duration,
    this.intensity = 1.0,
    this.sharpness = 0.5,
  }) : eventType = HapticEventType.hapticContinuous;

  /// Converts this event to an AHAP-compatible map.
  Map<String, dynamic> toAhapMap() {
    final eventParams = <Map<String, dynamic>>[
      {
        'ParameterID': 'HapticIntensity',
        'ParameterValue': intensity,
      },
      {
        'ParameterID': 'HapticSharpness',
        'ParameterValue': sharpness,
      },
    ];

    final map = <String, dynamic>{
      'Event': <String, dynamic>{
        'Time': time,
        'EventType': eventType == HapticEventType.hapticTransient
            ? 'HapticTransient'
            : 'HapticContinuous',
        'EventParameters': eventParams,
      },
    };

    if (eventType == HapticEventType.hapticContinuous) {
      (map['Event'] as Map<String, dynamic>)['EventDuration'] = duration;
    }

    return map;
  }

  /// Creates a [HapticEvent] from an AHAP event map.
  factory HapticEvent.fromAhapMap(Map<String, dynamic> map) {
    final event = map['Event'] as Map<String, dynamic>;
    final type = event['EventType'] as String;
    final time = (event['Time'] as num).toDouble();
    final duration = (event['EventDuration'] as num?)?.toDouble() ?? 0.0;

    final params = event['EventParameters'] as List<dynamic>? ?? [];
    double intensity = 1.0;
    double sharpness = 0.5;

    for (final param in params) {
      final p = param as Map<String, dynamic>;
      final id = p['ParameterID'] as String;
      final value = (p['ParameterValue'] as num).toDouble();
      if (id == 'HapticIntensity') {
        intensity = value;
      } else if (id == 'HapticSharpness') {
        sharpness = value;
      }
    }

    return HapticEvent(
      eventType: type == 'HapticTransient'
          ? HapticEventType.hapticTransient
          : HapticEventType.hapticContinuous,
      time: time,
      duration: duration,
      intensity: intensity,
      sharpness: sharpness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HapticEvent &&
          runtimeType == other.runtimeType &&
          eventType == other.eventType &&
          time == other.time &&
          duration == other.duration &&
          intensity == other.intensity &&
          sharpness == other.sharpness;

  @override
  int get hashCode => Object.hash(eventType, time, duration, intensity, sharpness);

  @override
  String toString() =>
      'HapticEvent(${eventType.name}, t=$time, d=$duration, i=$intensity, s=$sharpness)';
}
