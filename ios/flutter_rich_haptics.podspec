#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_rich_haptics.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_rich_haptics'
  s.version          = '0.1.0'
  s.summary          = 'Rich haptic feedback for Flutter with AHAP pattern support.'
  s.description      = <<-DESC
Rich haptic feedback plugin with AHAP pattern support,
iOS Core Haptics and Android VibrationEffect integration.
                       DESC
  s.homepage         = 'https://github.com/MasayukiYAMA/flutter_rich_haptics'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MasayukiYAMA' => 'https://github.com/MasayukiYAMA' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.frameworks = 'UIKit', 'CoreHaptics'
  s.weak_frameworks = 'CoreHaptics'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
