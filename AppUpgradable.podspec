Pod::Spec.new do |s|
  s.name             = 'AppUpgradable'
  s.version          = '1.1'
  s.summary          = 'Convenient way to migrate your app from one version to the next.'

  s.description      = <<-DESC
    AppUpgradable allows an app to easily and efficiently migrate from the last installed version to the newly installed version. It allows the migration function code to report out non-fatal errors and fatal errors. It allows the migrator to condense upgrades of multiple versions to help with performance. It has a single function to upgrade the app and returns the overall result.
                       DESC

  s.homepage         = 'https://github.com/Rivukis/AppUpgradable'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Brian Radebaugh' => 'Rivukis@gmail.com' }
  s.source           = { :git => 'https://github.com/Rivukis/AppUpgradable.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.swift_version = '4.0'
  s.source_files = 'AppUpgradable.playground/Sources/AppUpgradable.swift'
end
