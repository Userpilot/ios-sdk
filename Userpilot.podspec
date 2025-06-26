Pod::Spec.new do |spec|

  spec.name          = "Userpilot"
  spec.module_name   = "Userpilot"
  spec.version       = "1.0.1"
  spec.summary       = "Userpilot iOS SDK allows you to integrate Userpilot experiences into your native iOS apps"

  spec.description   = <<-DESC
  A Swift library for sending user properties and events to the Userpilot and retrieving and rendering Userpilot content based on those properties and events.
  DESC

  spec.homepage      = "https://github.com/Userpilot/ios-sdk"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "Userpilot" => "dev@userpilot.co" }

  spec.source        = { :git => "https://github.com/Userpilot/ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/Userpilot/**/*.swift"
  spec.exclude_files = 'Sources/Userpilot/Userpilot.docc'

  spec.swift_version = "5.0"
  spec.ios.deployment_target = "13.0"

  # Include all resources in the resource bundle
  spec.resource_bundles = {
      'Userpilot' => [
          'Sources/Userpilot/*.xcassets',
          'Sources/Userpilot/**/*.xib',
          'Sources/Userpilot/Resources/countries.json'
      ]
  }

  spec.dependency "SwiftPhoenixClient", "5.3.5"

end
