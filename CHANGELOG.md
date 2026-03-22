## 0.1.0

* Initial release with rich haptic feedback support
* 8 built-in presets: success, error, warning, buttonTap, selectionChange, celebration, streakMilestone, levelUp
* AHAP (Apple Haptic Audio Pattern) as unified format
* iOS: Core Haptics (iOS 13+) with UIFeedbackGenerator fallback
* Android: 3-tier support — VibrationEffect.Composition (API 30+), Waveform (API 26+), Legacy
* PatternBuilder fluent API for custom patterns
* HapticButton, HapticFeedbackWrapper, HapticScope widgets
