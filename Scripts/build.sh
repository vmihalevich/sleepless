#!/bin/sh
# Builds dist/Sleepless.app and dist/Sleepless-<version>.pkg. Needs Xcode and XcodeGen (brew install xcodegen).
#
#   DEVELOPER_DIR       Xcode to build with (default: /Applications/Xcode.app, whatever xcode-select says)
#   SIGN_IDENTITY       codesign identity (default: first "Developer ID Application", else ad hoc)
#   INSTALLER_IDENTITY  "Developer ID Installer: …" to sign the .pkg (optional)
#   NOTARY_PROFILE      notarytool keychain profile to notarize and staple the .pkg (optional, needs INSTALLER_IDENTITY)
set -eu
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP=Sleepless
VERSION=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
DIST=dist
BUNDLE="$DIST/$APP.app"
EXTENSION="$BUNDLE/Contents/PlugIns/SleeplessControl.appex"

rm -rf "$DIST" .build/xcode
mkdir -p "$DIST"

xcodegen generate --quiet
xcodebuild -project "$APP.xcodeproj" -target "$APP" -configuration Release \
	SYMROOT="$PWD/.build/xcode" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
	MARKETING_VERSION="$VERSION" -quiet build
ditto ".build/xcode/Release/$APP.app" "$BUNDLE"

if [ -z "${SIGN_IDENTITY:-}" ]; then
	SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
fi
if [ -n "$SIGN_IDENTITY" ]; then
	set -- --force --options runtime --timestamp --sign "$SIGN_IDENTITY"
else
	echo "No Developer ID found, signing ad hoc" >&2
	set -- --force --sign -
fi
# Inside out: the extension is sealed into the app's signature.
codesign "$@" --entitlements Control/SleeplessControl.entitlements "$EXTENSION"
codesign "$@" --entitlements Resources/Sleepless.entitlements "$BUNDLE"
codesign --verify --strict --deep "$BUNDLE"

# Staged under Applications/ so the payload installs to /Applications/Sleepless.app.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/root/Applications"
ditto "$BUNDLE" "$STAGE/root/Applications/$APP.app"

# Without this, Installer "relocates" the app to any other copy with the same bundle id (e.g. dist/).
pkgbuild --analyze --root "$STAGE/root" "$STAGE/components.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool false "$STAGE/components.plist"

pkgbuild \
	--root "$STAGE/root" \
	--component-plist "$STAGE/components.plist" \
	--scripts Installer/scripts \
	--identifier dev.mihalevich.sleepless \
	--version "$VERSION" \
	--install-location / \
	"$STAGE/$APP.pkg"

sed "s/@VERSION@/$VERSION/g" Installer/distribution.xml > "$STAGE/distribution.xml"
cp -R Installer/resources "$STAGE/resources"
PKG="$DIST/$APP-$VERSION.pkg"
set -- --distribution "$STAGE/distribution.xml" --package-path "$STAGE" --resources "$STAGE/resources"
if [ -n "${INSTALLER_IDENTITY:-}" ]; then
	set -- "$@" --sign "$INSTALLER_IDENTITY" --timestamp
fi
productbuild "$@" "$PKG"

if [ -n "${NOTARY_PROFILE:-}" ] && [ -n "${INSTALLER_IDENTITY:-}" ]; then
	xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
	xcrun stapler staple "$PKG"
fi

echo "Built $BUNDLE and $PKG"
