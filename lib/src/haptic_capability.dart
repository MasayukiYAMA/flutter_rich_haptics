/// Device haptic capability information.
class HapticCapability {
  /// Whether the device supports any haptic feedback.
  final bool supportsHaptics;

  /// The tier of haptic support available.
  final HapticTier tier;

  /// Additional device-specific info.
  final Map<String, dynamic> deviceInfo;

  const HapticCapability({
    required this.supportsHaptics,
    required this.tier,
    this.deviceInfo = const {},
  });

  factory HapticCapability.fromMap(Map<String, dynamic> map) {
    return HapticCapability(
      supportsHaptics: map['supportsHaptics'] as bool? ?? false,
      tier: HapticTier.values.firstWhere(
        (t) => t.name == (map['tier'] as String? ?? 'none'),
        orElse: () => HapticTier.none,
      ),
      deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'supportsHaptics': supportsHaptics,
        'tier': tier.name,
        'deviceInfo': deviceInfo,
      };

  /// No haptic support.
  static const none = HapticCapability(
    supportsHaptics: false,
    tier: HapticTier.none,
  );

  @override
  String toString() =>
      'HapticCapability(supports=$supportsHaptics, tier=${tier.name})';
}

/// Tier of haptic engine support.
enum HapticTier {
  /// No haptic support.
  none,

  /// Basic vibration (legacy Android, pre-iOS 13).
  legacy,

  /// Waveform vibration (Android API 26-29).
  waveform,

  /// Full composition support (Android API 30+, iOS 13+ with Core Haptics).
  composition,
}
