# Development

## Build environment

Use a full Xcode installation and complete its first-launch setup. The macOS deployment target is 12.0. CocoaPods dependencies are included in the repository; `pod install` is only needed when updating them.

Run the commands below from the repository root. Select your Xcode installation, adjusting the path if needed:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Local build

Build the development app on Apple silicon with ad hoc signing. On Intel Macs, replace `arch=arm64` with `arch=x86_64` in the build and test commands.

```sh
xcodebuild -workspace Yippy.xcworkspace \
  -scheme 'Yippy Beta' -configuration 'Beta Debug' \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

The app is `build/DerivedData/Build/Products/Beta Debug/Yippy Beta.app`. It uses separate preferences and history from upstream Yippy. Automatic paste requires Accessibility permission. This locally signed build is for development.

## Tests

Run the focused history, paste preparation, and settings tests:

```sh
xcodebuild -workspace Yippy.xcworkspace \
  -scheme 'Yippy XCTest' -configuration XCTest \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  -only-testing:YippyTests/YippyHistoryTests \
  -only-testing:YippyTests/HistoryItemTests \
  -only-testing:YippyTests/SettingsTests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

These tests cover history selection, plain-text preparation, data preservation, and preferences. Automatic paste into other applications requires separate manual testing.
