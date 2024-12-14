Pod::Spec.new do |spec|

  spec.name          = "Userpilot"
  spec.module_name   = "Userpilot"
  spec.version       = "0.0.1-beta.2"
  spec.summary       = "Userpilot iOS SDK allows you to integrate Userpilot experiences into your native iOS apps"

  spec.description   = <<-DESC
  A Swift library for sending user properties and events to the Userpilot and retrieving and rendering Userpilot content based on those properties and events.
                   DESC

  spec.homepage      = "https://github.com/Userpilot/ios-sdk"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "motasem-userpilot" => "motasem@userpilot.co" }

  spec.source        = { :git => "https://github.com/Userpilot/ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/UserPilot/**/*.swift"
  spec.exclude_files = 'Sources/UserPilot/Userpilot.docc'

  spec.swift_version = "5.0"
  spec.ios.deployment_target = "13.0"

  spec.resource_bundles = {
      'UserPilot' => ['Sources/UserPilot/*.xcassets']
  }

  spec.dependency "SwiftPhoenixClient", "~> 5.2.2"

end
