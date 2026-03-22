import 'package:flutter/material.dart';
import 'package:flutter_rich_haptics/flutter_rich_haptics.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rich Haptics Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HapticsDemoPage(),
    );
  }
}

class HapticsDemoPage extends StatefulWidget {
  const HapticsDemoPage({super.key});

  @override
  State<HapticsDemoPage> createState() => _HapticsDemoPageState();
}

class _HapticsDemoPageState extends State<HapticsDemoPage> {
  final _engine = HapticEngine.instance;
  HapticCapability _capability = HapticCapability.none;
  bool _initialized = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initHaptics();
  }

  Future<void> _initHaptics() async {
    try {
      final success = await _engine.initialize();
      final cap = await _engine.getCapabilities();
      setState(() {
        _initialized = success;
        _capability = cap;
        _status = success ? 'Ready (${cap.tier.name})' : 'Init failed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rich Haptics Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCapabilityCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('Presets'),
          ..._buildPresetButtons(),
          const SizedBox(height: 24),
          _buildSectionTitle('Custom Builder'),
          _buildBuilderDemo(),
          const SizedBox(height: 24),
          _buildSectionTitle('Widgets'),
          _buildWidgetDemo(),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Supports Haptics: ${_capability.supportsHaptics}'),
            Text('Tier: ${_capability.tier.name}'),
            if (_capability.deviceInfo.isNotEmpty)
              Text('Device: ${_capability.deviceInfo}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  List<Widget> _buildPresetButtons() {
    final presets = <String, (String, HapticPattern)>{
      'success': ('Success (da-DUM)', HapticPreset.success),
      'error': ('Error (double buzz)', HapticPreset.error),
      'warning': ('Warning (tap + tail)', HapticPreset.warning),
      'buttonTap': ('Button Tap', HapticPreset.buttonTap),
      'selectionChange': ('Selection Change', HapticPreset.selectionChange),
      'celebration': ('Celebration (fireworks)', HapticPreset.celebration),
      'streakMilestone': ('Streak Milestone (drum roll)', HapticPreset.streakMilestone),
      'levelUp': ('Level Up (power-up)', HapticPreset.levelUp),
    };

    return presets.entries.map((entry) {
      final label = entry.value.$1;
      final pattern = entry.value.$2;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _initialized ? () => _playPattern(label, pattern) : null,
            child: Text(label),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBuilderDemo() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _initialized ? _playCustomPattern : null,
        icon: const Icon(Icons.build),
        label: const Text('Play Custom Pattern (Builder)'),
      ),
    );
  }

  Widget _buildWidgetDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HapticButton(
          hapticPattern: HapticPreset.buttonTap,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('HapticButton tapped!'),
                  duration: Duration(milliseconds: 500)),
            );
          },
          child: const Text('HapticButton'),
        ),
        const SizedBox(height: 8),
        HapticFeedbackWrapper(
          hapticPattern: HapticPreset.selectionChange,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('HapticFeedbackWrapper tapped!'),
                  duration: Duration(milliseconds: 500)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Tap me (HapticFeedbackWrapper)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _playPattern(String name, HapticPattern pattern) async {
    try {
      await _engine.play(pattern);
      setState(() => _status = 'Played: $name');
    } catch (e) {
      setState(() => _status = 'Error playing $name: $e');
    }
  }

  Future<void> _playCustomPattern() async {
    final pattern = PatternBuilder()
        .addTransient(time: 0.0, intensity: 0.3, sharpness: 0.9)
        .addTransient(time: 0.08, intensity: 0.5, sharpness: 0.9)
        .addTransient(time: 0.16, intensity: 0.8, sharpness: 0.9)
        .addContinuous(time: 0.25, duration: 0.3, intensity: 0.6, sharpness: 0.4)
        .addIntensityCurve(
          time: 0.25,
          points: [(0.0, 0.6), (0.15, 1.0), (0.3, 0.0)],
        )
        .build();

    try {
      await _engine.play(pattern);
      setState(() => _status = 'Played: Custom Pattern');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }
}
