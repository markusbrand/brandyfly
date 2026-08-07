#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint brandyfly_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'brandyfly_native'
  s.version          = '0.0.1'
 s.summary          = 'Native Android and iOS platform boundary for BrandyFly.'
  s.description      = <<-DESC
Native Android and iOS platform boundary for BrandyFly.
                       DESC
 s.homepage         = 'https://github.com/markusbrand/brandyfly'
  s.license          = { :file => '../LICENSE' }
 s.author           = { 'BrandyFly contributors' => 'https://github.com/markusbrand' }
  s.source           = { :path => '.' }
  s.source_files = 'brandyfly_native/Sources/brandyfly_native/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'brandyfly_native_privacy' => ['brandyfly_native/Sources/brandyfly_native/PrivacyInfo.xcprivacy']}
end
