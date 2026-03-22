/// A control point in a parameter curve.
class HapticParameterControlPoint {
  /// Time of this control point in seconds.
  final double time;

  /// Value at this control point (0.0 to 1.0).
  final double value;

  const HapticParameterControlPoint({
    required this.time,
    required this.value,
  });

  Map<String, dynamic> toAhapMap() => {
        'Time': time,
        'ParameterValue': value,
      };

  factory HapticParameterControlPoint.fromAhapMap(Map<String, dynamic> map) {
    return HapticParameterControlPoint(
      time: (map['Time'] as num).toDouble(),
      value: (map['ParameterValue'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HapticParameterControlPoint &&
          time == other.time &&
          value == other.value;

  @override
  int get hashCode => Object.hash(time, value);
}

/// The parameter ID for a parameter curve.
enum HapticParameterId {
  hapticIntensityControl,
  hapticSharpnessControl,
}

/// A parameter curve that modulates a haptic property over time.
class HapticParameterCurve {
  /// Which parameter this curve controls.
  final HapticParameterId parameterId;

  /// Time offset for this curve.
  final double time;

  /// Control points defining the curve shape.
  final List<HapticParameterControlPoint> controlPoints;

  const HapticParameterCurve({
    required this.parameterId,
    required this.time,
    required this.controlPoints,
  });

  Map<String, dynamic> toAhapMap() => {
        'ParameterCurve': {
          'ParameterID': parameterId == HapticParameterId.hapticIntensityControl
              ? 'HapticIntensityControl'
              : 'HapticSharpnessControl',
          'Time': time,
          'ParameterCurveControlPoints': controlPoints
              .map((cp) => cp.toAhapMap())
              .toList(),
        },
      };

  factory HapticParameterCurve.fromAhapMap(Map<String, dynamic> map) {
    final curve = map['ParameterCurve'] as Map<String, dynamic>;
    final idStr = curve['ParameterID'] as String;
    final points = (curve['ParameterCurveControlPoints'] as List<dynamic>)
        .map((p) =>
            HapticParameterControlPoint.fromAhapMap(p as Map<String, dynamic>))
        .toList();

    return HapticParameterCurve(
      parameterId: idStr == 'HapticIntensityControl'
          ? HapticParameterId.hapticIntensityControl
          : HapticParameterId.hapticSharpnessControl,
      time: (curve['Time'] as num).toDouble(),
      controlPoints: points,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HapticParameterCurve &&
          parameterId == other.parameterId &&
          time == other.time;

  @override
  int get hashCode => Object.hash(parameterId, time);
}
