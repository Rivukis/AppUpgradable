# AppUpgradable

[![Version](https://img.shields.io/cocoapods/v/AppUpgradable.svg?style=flat)](http://cocoapods.org/pods/AppUpgradable)
[![License](https://img.shields.io/cocoapods/l/AppUpgradable.svg?style=flat)](http://cocoapods.org/pods/AppUpgradable)
[![Platform](https://img.shields.io/cocoapods/p/AppUpgradable.svg?style=flat)](http://cocoapods.org/pods/AppUpgradable)

Convenient way to migrate your app from one version to the next.

AppUpgradable allows an app to easily and efficiently migrate from the last installed version to the newly installed version. It allows the migration function code to report out non-fatal errors and fatal errors. It allows the migrator to condense upgrades of multiple versions to help with performance. It has a single function to upgrade the app and returns the overall result.

## Conforming to AppUpgradable

// TODO: fill out explanation and examlpe code.

## Tests

// TODO: write tests (currently manually testing functionality in the playground)

To see and run the tests for `AppUpgradable`. Download the playground and run it. The tests are written using [Deft](https://github.com/Rivukis/Deft).

## Requirements

* Xcode 9
* Swift 4

## Installation

AppUpgradable is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
platform :ios, "9.0"
use_frameworks!

target "<YOUR_TARGET>" do
    pod "AppUpgradable"
end
```

## Author

Brian Radebaugh, radebaughbrian@gmail.com

## License

AppUpgradable is available under the MIT license. See the LICENSE file for more info.
