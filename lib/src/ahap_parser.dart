import 'dart:convert';

import 'haptic_pattern.dart';

/// Parses and serializes AHAP (Apple Haptic Audio Pattern) JSON.
class AhapParser {
  const AhapParser._();

  /// Parses an AHAP JSON string into a [HapticPattern].
  static HapticPattern parse(String ahapJson) {
    final map = json.decode(ahapJson) as Map<String, dynamic>;
    return HapticPattern.fromAhapMap(map);
  }

  /// Serializes a [HapticPattern] to an AHAP JSON string.
  static String serialize(HapticPattern pattern) {
    return json.encode(pattern.toAhapMap());
  }

  /// Validates an AHAP JSON string and returns any errors found.
  /// Returns an empty list if valid.
  static List<String> validate(String ahapJson) {
    final errors = <String>[];

    Map<String, dynamic> map;
    try {
      map = json.decode(ahapJson) as Map<String, dynamic>;
    } catch (e) {
      return ['Invalid JSON: $e'];
    }

    if (!map.containsKey('Version')) {
      errors.add('Missing required field: Version');
    }

    if (!map.containsKey('Pattern')) {
      errors.add('Missing required field: Pattern');
    } else {
      final pattern = map['Pattern'];
      if (pattern is! List) {
        errors.add('Pattern must be an array');
      } else {
        for (var i = 0; i < pattern.length; i++) {
          final element = pattern[i];
          if (element is! Map) {
            errors.add('Pattern[$i] must be an object');
            continue;
          }
          final el = element as Map<String, dynamic>;
          if (!el.containsKey('Event') && !el.containsKey('ParameterCurve')) {
            errors.add(
                'Pattern[$i] must contain either Event or ParameterCurve');
          }
          if (el.containsKey('Event')) {
            final event = el['Event'] as Map<String, dynamic>;
            if (!event.containsKey('Time')) {
              errors.add('Pattern[$i].Event missing Time');
            }
            if (!event.containsKey('EventType')) {
              errors.add('Pattern[$i].Event missing EventType');
            } else {
              final type = event['EventType'];
              if (type != 'HapticTransient' && type != 'HapticContinuous') {
                errors.add(
                    'Pattern[$i].Event.EventType must be HapticTransient or HapticContinuous');
              }
            }
          }
        }
      }
    }

    return errors;
  }
}
