Pod::Spec.new do |spec|

  spec.name         = "UserPilot"
  spec.module_name  = "UserPilot"
  spec.version      = "0.0.1"
  spec.summary      = "UserPilot iOS SDK allows you to integrate UserPilot experiences into your native iOS apps"

  spec.description  = <<-DESC
  A Swift library for sending user properties and events to the UserPilot and retrieving and rendering UserPilot content based on those properties and events.
                   DESC

  spec.homepage     = "https://github.com/Userpilot/ios-sdk"
  spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  spec.author             = { "motasem-userpilot" => "motasem@userpilot.co" }

  spec.source       = { :git => "https://github.com/Userpilot/ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/UserPilot/**/*.swift"

  spec.swift_version = "5.0"
  spec.ios.deployment_target = "15.0"

  spec.resource_bundles = {
      'UserPilot' => ['Sources/UserPilot/**/*.xcassets']
  }

  spec.dependency "SwiftPhoenixClient", "~> 5.2.2"

end
