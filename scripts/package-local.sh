#!/bin/sh
# Build a local Universal archive. This does not sign for distribution or upload.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

xcodebuild -workspace Yippy.xcworkspace \
  -scheme Yippy -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/LocalRelease \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  ENABLE_HARDENED_RUNTIME=NO build

app='build/LocalRelease/Build/Products/Release/Yippy2.app'
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
[ "$bundle_id" = io.github.bbbiggest.yippy2 ] || { echo 'Unexpected application identity.' >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
archive="Yippy2-$version-$build-local-universal.zip"

verify_binary() {
  architectures=" $(lipo -archs "$1") "
  for architecture in arm64 x86_64; do
    case "$architectures" in
      *" $architecture "*) ;;
      *) echo "Missing $architecture architecture: $1" >&2; exit 1 ;;
    esac
  done
}

verify_app() {
  codesign --verify --deep --strict "$1"
  verify_binary "$1/Contents/MacOS/Yippy2"
  for framework in "$1"/Contents/Frameworks/*.framework; do
    [ -d "$framework" ] || continue
    executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$framework/Resources/Info.plist")
    verify_binary "$framework/$executable"
  done
}

verify_app "$app"
stage=$(mktemp -d build/.yippy2-package.XXXXXX)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir "$stage/payload" "$stage/extracted"
ditto "$app" "$stage/payload/Yippy2.app"
cp LICENSE "$stage/payload/LICENSE"
ditto -c -k --sequesterRsrc "$stage/payload" "$stage/$archive"
unzip -tq "$stage/$archive"
ditto -x -k "$stage/$archive" "$stage/extracted"
verify_app "$stage/extracted/Yippy2.app"
cmp LICENSE "$stage/extracted/LICENSE"
mv "$stage/$archive" "build/$archive"
(cd build && shasum -a 256 "$archive" > "$archive.sha256")
echo "Local development archive: build/$archive"
echo 'Ad hoc signed; Developer ID signing and notarization are required before public distribution.'
