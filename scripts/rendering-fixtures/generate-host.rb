# Generate a disposable app-hosted test project without changing the SDK package
# or its customer samples. All test sources remain in their original checkout.
require 'xcodeproj'

sdk_root, output = ARGV
abort 'Usage: generate-host.rb SDK_ROOT OUTPUT_DIRECTORY' unless sdk_root && output
project = Xcodeproj::Project.new(File.join(output, 'RenderHost.xcodeproj'))
app = project.new_target(:application, 'RenderHost', :ios, '13.0')
tests = project.new_target(:unit_test_bundle, 'HostedRenderTests', :ios, '13.0')
ui_tests = project.new_target(:ui_test_bundle, 'RendererGestureTests', :ios, '13.0')
tests.add_dependency(app)
ui_tests.add_dependency(app)
app_source = File.join(sdk_root, 'scripts/rendering-fixtures/App.swift')
app.add_file_references([project.main_group.new_file(app_source)])
%w[scripts/rendering-fixtures/CarouselFixture.swift Tests/UserpilotTests/MockUserpilot.swift
   Tests/UserpilotTests/Experiences/MockContentFactory.swift].each do |path|
  app.add_file_references([project.main_group.new_file(File.join(sdk_root, path))])
end
%w[CarouselGestureTests.swift CarouselDirectionTests.swift VoiceOverFixtureTests.swift].each do |name|
  ui_tests.add_file_references([project.main_group.new_file(
    File.join(sdk_root, 'scripts/rendering-fixtures', name))])
end
Dir.glob(File.join(sdk_root, 'Tests/UserpilotTests/**/*.swift')).sort.each do |file|
  tests.add_file_references([project.main_group.new_file(file)])
end

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = sdk_root
project.root_object.package_references << package
[app, tests].each do |target|
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package
  product.product_name = 'Userpilot'
  target.package_product_dependencies << product
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product
  target.frameworks_build_phase.files << build_file
end

[app, tests, ui_tests].each do |target|
  target.build_configurations.each do |configuration|
    configuration.build_settings.merge!(
      'SWIFT_VERSION' => '5.0',
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'CODE_SIGNING_ALLOWED' => 'NO',
      'PRODUCT_BUNDLE_IDENTIFIER' => "com.userpilot.validation.#{target.name}",
      'ENABLE_TESTABILITY' => 'YES',
      'TARGETED_DEVICE_FAMILY' => '1,2'
    )
  end
end
app.build_configurations.each do |configuration|
  configuration.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  configuration.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
end
tests.build_configurations.each do |configuration|
  configuration.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/RenderHost.app/RenderHost'
  configuration.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui_tests.build_configurations.each do |configuration|
  configuration.build_settings['TEST_TARGET_NAME'] = 'RenderHost'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui_tests)
scheme.set_launch_target(app)
scheme.save_as(project.path, 'RenderHost')
