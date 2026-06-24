Pod::Spec.new do |spec|

  spec.name          = "Userpilot"
  spec.module_name   = "Userpilot"
  spec.version       = "1.2.0"
  spec.summary       = "Userpilot iOS SDK allows you to integrate Userpilot experiences into your native iOS apps"

  spec.description   = <<-DESC
  A Swift library for sending user properties and events to the Userpilot and retrieving and rendering Userpilot content based on those properties and events.
  DESC

  spec.homepage      = "https://github.com/Userpilot/ios-sdk"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "Userpilot" => "dev@userpilot.com" }

  spec.source        = { :git => "https://github.com/Userpilot/ios-sdk.git", :tag => "#{spec.version}" }
  # Swift SDK + the Objective-C exception-guard shims (public API only).
  # Under CocoaPods everything is a single module: the ObjC headers are exposed
  # via the module umbrella so the SDK's own Swift can use them (the Swift sources
  # guard the import with `#if canImport(UserpilotObjC)`, which is true only under SPM).
  # They are intentionally NOT private_header_files — private headers are excluded
  # from the umbrella and would be invisible to the pod's own Swift.
  spec.source_files  = "Sources/Userpilot/**/*.swift", "Sources/UserpilotObjC/**/*.{h,m}"
  spec.exclude_files = 'Sources/Userpilot/Userpilot.docc'

  spec.swift_version = "5.0"
  spec.ios.deployment_target = "13.0"

  # Include all resources in the resource bundle
  spec.resource_bundles = {
      'Userpilot' => [
          'Sources/Userpilot/PrivacyInfo.xcprivacy',
          'Sources/Userpilot/*.xcassets',
          'Sources/Userpilot/**/*.xib',
          'Sources/Userpilot/Resources/countries.json'
      ]
  }

end
