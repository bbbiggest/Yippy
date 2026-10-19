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

To build and package a local Universal version of Yippy2 for both Intel and Apple silicon:

```sh
./scripts/package-local.sh
```

The `Yippy` scheme produces `build/LocalRelease/Build/Products/Release/Yippy2.app`; the ZIP and SHA-256 checksum are written to `build/`. Yippy2 uses bundle identifier `io.github.bbbiggest.yippy2`, with separate preferences and history from upstream Yippy and Yippy Beta. Existing data is not imported. The package is ad hoc signed for local testing; public distribution requires Developer ID signing and notarization.

## Tests

Run the focused history, paste preparation, and settings tests:

```sh
xcodebuild -workspace Yippy.xcworkspace \
  -scheme 'Yippy XCTest' -configuration XCTest \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  -only-testing:YippyTests/YippyHistoryTests \
  -only-testing:YippyTests/URLEncodingTests \
  -only-testing:YippyTests/HistoryItemTests \
  -only-testing:YippyTests/SettingsTests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

These tests cover history selection, paste preparation, data preservation, and preferences. Automatic paste into other applications requires separate manual testing.
