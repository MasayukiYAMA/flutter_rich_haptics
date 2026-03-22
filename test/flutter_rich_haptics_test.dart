import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rich_haptics/flutter_rich_haptics.dart';

void main() {
  group('HapticEvent', () {
    test('transient constructor sets correct defaults', () {
      const event = HapticEvent.transient(time: 0.5, intensity: 0.8);
      expect(event.eventType, HapticEventType.hapticTransient);
      expect(event.time, 0.5);
      expect(event.intensity, 0.8);
      expect(event.sharpness, 0.5);
      expect(event.duration, 0.0);
    });

    test('continuous constructor sets duration', () {
      const event = HapticEvent.continuous(
        time: 0.1,
        duration: 0.3,
        intensity: 0.6,
        sharpness: 0.7,
      );
      expect(event.eventType, HapticEventType.hapticContinuous);
      expect(event.duration, 0.3);
    });

    test('toAhapMap produces valid AHAP event', () {
      const event = HapticEvent.transient(time: 0.0, intensity: 1.0, sharpness: 0.5);
      final map = event.toAhapMap();
      final eventMap = map['Event'] as Map<String, dynamic>;
      expect(eventMap['Time'], 0.0);
      expect(eventMap['EventType'], 'HapticTransient');
      final params = eventMap['EventParameters'] as List;
      expect(params.length, 2);
    });

    test('continuous event includes EventDuration in AHAP', () {
      const event = HapticEvent.continuous(time: 0.1, duration: 0.5);
      final map = event.toAhapMap();
      final eventMap = map['Event'] as Map<String, dynamic>;
      expect(eventMap['EventDuration'], 0.5);
      expect(eventMap['EventType'], 'HapticContinuous');
    });

    test('fromAhapMap roundtrips correctly', () {
      const original = HapticEvent.transient(time: 0.2, intensity: 0.7, sharpness: 0.3);
      final reconstructed = HapticEvent.fromAhapMap(original.toAhapMap());
      expect(reconstructed, original);
    });

    test('equality works', () {
      const a = HapticEvent.transient(time: 0.0, intensity: 0.5);
      const b = HapticEvent.transient(time: 0.0, intensity: 0.5);
      const c = HapticEvent.transient(time: 0.1, intensity: 0.5);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('HapticPattern', () {
    test('toAhapMap includes version and pattern', () {
      final pattern = HapticPattern(events: [
        HapticEvent.transient(time: 0.0, intensity: 0.5, sharpness: 0.6),
      ]);
      final map = pattern.toAhapMap();
      expect(map['Version'], 1.0);
      expect(map['Pattern'], isA<List>());
      expect((map['Pattern'] as List).length, 1);
    });

    test('fromAhapMap parses events and curves', () {
      final ahap = {
        'Version': 1.0,
        'Pattern': [
          {
            'Event': {
              'Time': 0.0,
              'EventType': 'HapticTransient',
              'EventParameters': [
                {'ParameterID': 'HapticIntensity', 'ParameterValue': 0.8},
                {'ParameterID': 'HapticSharpness', 'ParameterValue': 0.6},
              ],
            },
          },
          {
            'ParameterCurve': {
              'ParameterID': 'HapticIntensityControl',
              'Time': 0.0,
              'ParameterCurveControlPoints': [
                {'Time': 0.0, 'ParameterValue': 0.5},
                {'Time': 0.3, 'ParameterValue': 1.0},
              ],
            },
          },
        ],
      };
      final pattern = HapticPattern.fromAhapMap(ahap);
      expect(pattern.events.length, 1);
      expect(pattern.parameterCurves.length, 1);
      expect(pattern.events[0].intensity, 0.8);
    });

    test('totalDuration computes correctly', () {
      final pattern = HapticPattern(events: [
        HapticEvent.transient(time: 0.0),
        HapticEvent.continuous(time: 0.2, duration: 0.5),
      ]);
      expect(pattern.totalDuration, 0.7);
    });
  });

  group('AhapParser', () {
    test('parse and serialize roundtrip', () {
      final original = HapticPattern(events: [
        HapticEvent.transient(time: 0.0, intensity: 0.5, sharpness: 0.6),
        HapticEvent.continuous(
            time: 0.1, duration: 0.3, intensity: 0.8, sharpness: 0.4),
      ]);
      final json = AhapParser.serialize(original);
      final parsed = AhapParser.parse(json);
      expect(parsed.events.length, 2);
      expect(parsed.events[0].eventType, HapticEventType.hapticTransient);
      expect(parsed.events[1].eventType, HapticEventType.hapticContinuous);
      expect(parsed.events[1].duration, 0.3);
    });

    test('validate returns empty for valid AHAP', () {
      final pattern = HapticPattern(events: [
        HapticEvent.transient(time: 0.0),
      ]);
      final ahapJson = AhapParser.serialize(pattern);
      final errors = AhapParser.validate(ahapJson);
      expect(errors, isEmpty);
    });

    test('validate catches missing Version', () {
      final errors = AhapParser.validate('{"Pattern": []}');
      expect(errors, contains('Missing required field: Version'));
    });

    test('validate catches missing Pattern', () {
      final errors = AhapParser.validate('{"Version": 1.0}');
      expect(errors, contains('Missing required field: Pattern'));
    });

    test('validate catches invalid JSON', () {
      final errors = AhapParser.validate('not json');
      expect(errors.length, 1);
      expect(errors[0], startsWith('Invalid JSON:'));
    });

    test('validate catches invalid event type', () {
      final errors = AhapParser.validate(json.encode({
        'Version': 1.0,
        'Pattern': [
          {
            'Event': {
              'Time': 0.0,
              'EventType': 'InvalidType',
            },
          },
        ],
      }));
      expect(errors, isNotEmpty);
    });
  });

  group('PatternBuilder', () {
    test('builds pattern with transient events', () {
      final pattern = PatternBuilder()
          .addTransient(time: 0.0, intensity: 0.5, sharpness: 0.6)
          .addTransient(time: 0.1, intensity: 1.0)
          .build();
      expect(pattern.events.length, 2);
      expect(pattern.events[0].intensity, 0.5);
      expect(pattern.events[1].intensity, 1.0);
    });

    test('builds pattern with continuous events', () {
      final pattern = PatternBuilder()
          .addContinuous(time: 0.0, duration: 0.5, intensity: 0.8)
          .build();
      expect(pattern.events.length, 1);
      expect(pattern.events[0].eventType, HapticEventType.hapticContinuous);
      expect(pattern.events[0].duration, 0.5);
    });

    test('builds pattern with parameter curves', () {
      final pattern = PatternBuilder()
          .addContinuous(time: 0.0, duration: 0.5)
          .addIntensityCurve(
            time: 0.0,
            points: [(0.0, 0.2), (0.25, 0.8), (0.5, 0.0)],
          )
          .addSharpnessCurve(
            time: 0.0,
            points: [(0.0, 0.5), (0.5, 1.0)],
          )
          .build();
      expect(pattern.parameterCurves.length, 2);
      expect(pattern.parameterCurves[0].controlPoints.length, 3);
    });

    test('built pattern serializes to valid AHAP', () {
      final pattern = PatternBuilder()
          .addTransient(time: 0.0, intensity: 0.8, sharpness: 0.6)
          .build();
      final ahapJson = AhapParser.serialize(pattern);
      final errors = AhapParser.validate(ahapJson);
      expect(errors, isEmpty);
    });
  });

  group('HapticPreset', () {
    test('all 8 presets are defined', () {
      expect(HapticPreset.all.length, 8);
      expect(HapticPreset.all.keys, containsAll([
        'success', 'error', 'warning', 'buttonTap',
        'selectionChange', 'celebration', 'streakMilestone', 'levelUp',
      ]));
    });

    test('success preset has 2 transient events', () {
      expect(HapticPreset.success.events.length, 2);
      for (final event in HapticPreset.success.events) {
        expect(event.eventType, HapticEventType.hapticTransient);
      }
    });

    test('error preset has transient + continuous + transient', () {
      final events = HapticPreset.error.events;
      expect(events.length, 3);
      expect(events[0].eventType, HapticEventType.hapticTransient);
      expect(events[1].eventType, HapticEventType.hapticContinuous);
      expect(events[2].eventType, HapticEventType.hapticTransient);
    });

    test('celebration has parameter curves', () {
      expect(HapticPreset.celebration.parameterCurves, isNotEmpty);
    });

    test('levelUp has multiple parameter curves', () {
      expect(HapticPreset.levelUp.parameterCurves.length, 2);
    });

    test('all presets serialize to valid AHAP', () {
      for (final entry in HapticPreset.all.entries) {
        final ahapJson = AhapParser.serialize(entry.value);
        final errors = AhapParser.validate(ahapJson);
        expect(errors, isEmpty, reason: 'Preset ${entry.key} has invalid AHAP');
      }
    });

    test('all presets roundtrip through AHAP', () {
      for (final entry in HapticPreset.all.entries) {
        final ahapJson = AhapParser.serialize(entry.value);
        final parsed = AhapParser.parse(ahapJson);
        expect(parsed.events.length, entry.value.events.length,
            reason: 'Preset ${entry.key} event count mismatch after roundtrip');
      }
    });

    test('buttonTap is a single light tap', () {
      expect(HapticPreset.buttonTap.events.length, 1);
      expect(HapticPreset.buttonTap.events[0].intensity, 0.4);
      expect(HapticPreset.buttonTap.events[0].sharpness, 0.8);
    });

    test('selectionChange is very light', () {
      expect(HapticPreset.selectionChange.events.length, 1);
      expect(HapticPreset.selectionChange.events[0].intensity, 0.2);
    });

    test('streakMilestone has escalating transients', () {
      final events = HapticPreset.streakMilestone.events;
      expect(events.length, 7);
      // First 5 should be escalating transients
      for (var i = 0; i < 4; i++) {
        expect(events[i].intensity, lessThan(events[i + 1].intensity));
      }
    });
  });

  group('HapticCapability', () {
    test('fromMap creates correct capability', () {
      final cap = HapticCapability.fromMap({
        'supportsHaptics': true,
        'tier': 'composition',
        'deviceInfo': {'model': 'iPhone 15'},
      });
      expect(cap.supportsHaptics, true);
      expect(cap.tier, HapticTier.composition);
      expect(cap.deviceInfo['model'], 'iPhone 15');
    });

    test('none constant', () {
      expect(HapticCapability.none.supportsHaptics, false);
      expect(HapticCapability.none.tier, HapticTier.none);
    });

    test('toMap roundtrips', () {
      final original = HapticCapability(
        supportsHaptics: true,
        tier: HapticTier.waveform,
        deviceInfo: {'apiLevel': 28},
      );
      final map = original.toMap();
      final restored = HapticCapability.fromMap(map);
      expect(restored.supportsHaptics, original.supportsHaptics);
      expect(restored.tier, original.tier);
    });
  });

  group('HapticParameterCurve', () {
    test('toAhapMap produces valid structure', () {
      final curve = HapticParameterCurve(
        parameterId: HapticParameterId.hapticIntensityControl,
        time: 0.0,
        controlPoints: [
          HapticParameterControlPoint(time: 0.0, value: 0.5),
          HapticParameterControlPoint(time: 0.3, value: 1.0),
        ],
      );
      final map = curve.toAhapMap();
      expect(map.containsKey('ParameterCurve'), true);
      final curveMap = map['ParameterCurve'] as Map<String, dynamic>;
      expect(curveMap['ParameterID'], 'HapticIntensityControl');
      expect(curveMap['Time'], 0.0);
      expect((curveMap['ParameterCurveControlPoints'] as List).length, 2);
    });

    test('fromAhapMap roundtrips', () {
      final original = HapticParameterCurve(
        parameterId: HapticParameterId.hapticSharpnessControl,
        time: 0.1,
        controlPoints: [
          HapticParameterControlPoint(time: 0.0, value: 0.2),
          HapticParameterControlPoint(time: 0.5, value: 0.9),
        ],
      );
      final map = original.toAhapMap();
      final restored = HapticParameterCurve.fromAhapMap(map);
      expect(restored.parameterId, HapticParameterId.hapticSharpnessControl);
      expect(restored.time, 0.1);
      expect(restored.controlPoints.length, 2);
    });
  });
}
