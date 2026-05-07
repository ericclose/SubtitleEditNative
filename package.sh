#!/bin/bash
set -e

APP_NAME="Subtitle Edit Native"
BUNDLE_ID="com.subtitleedit.native"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🚀 Starting Build Process..."

# 1. Clean previous build
rm -rf dist
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Auto-detect .NET binary if not provided
if [ -z "$DOTNET_BIN" ]; then
    if command -v dotnet &> /dev/null; then
        DOTNET_BIN="dotnet"
    elif [ -f "$HOME/.dotnet/dotnet" ]; then
        DOTNET_BIN="$HOME/.dotnet/dotnet"
    else
        echo "❌ Error: 'dotnet' not found. Please install .NET 9 or set DOTNET_BIN."
        exit 1
    fi
fi

echo "🔍 Using .NET: $DOTNET_BIN"

# 2. Build .NET Bridge (Native AOT)
echo "📦 Building .NET Bridge (Native AOT)..."
"${DOTNET_BIN}" publish -c Release -r osx-arm64 --self-contained true /p:PublishAot=true /p:NativeLib=Shared -o bin/Native LibSEBridge/LibSEBridge.csproj
cp bin/Native/*.dylib "${MACOS_DIR}/"

# 3. Build Swift App using SPM
echo "🍎 Compiling Swift App using SPM..."
swift build -c release --product SENativeApp
cp .build/release/SENativeApp "${MACOS_DIR}/"

# 4. Copy Info.plist and update version
cp Info.plist "${CONTENTS_DIR}/"
VERSION=$(cat VERSION | tr -d '\n')
echo "🏷️  Setting version to ${VERSION}..."
plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"

# 5. Create DMG
echo "💿 Creating DMG..."
ln -s /Applications dist/Applications
ARCH="arm64"
DMG_NAME="SubtitleEditNative_v${VERSION}_macOS_${ARCH}.dmg"
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder dist -ov -format UDZO "${DMG_NAME}"
rm -f dist/Applications

echo "✅ Build Complete: ${DMG_NAME}"
