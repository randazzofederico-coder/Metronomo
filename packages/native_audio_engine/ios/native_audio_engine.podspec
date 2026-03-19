#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_audio_engine.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_audio_engine'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../src/soundtouch_wrapper.{h,cpp}', '../src/soundtouch/source/SoundTouch/*.{h,cpp}'
  s.public_header_files = 'Classes/**/*.h', '../src/soundtouch_wrapper.h'
  
  # Add SoundTouch include directories
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src/soundtouch/include" "$(PODS_TARGET_SRCROOT)/../src"',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'ST_NO_EXCEPTION_HANDLING=1'
  }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'native_audio_engine_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

end
