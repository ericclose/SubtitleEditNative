#!/bin/zsh

# 1. Clean and Build
echo "Step 1: Building with Swift Package Manager..."
swift build -c release --arch arm64

# 2. Create App Bundle Structure
echo "Step 2: Creating App Bundle structure..."
APP_NAME="MacOSVideoProto"
BUNDLE_DIR=".build/release/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
PLUGINS_DIR="${MACOS_DIR}/plugins"

rm -rf "${CONTENTS_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${PLUGINS_DIR}"

# 3. Copy Executable, Info.plist, and Icons from Resources/
echo "Step 3: Restoring Icons and Metadata from Resources..."
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"
cp "Resources/Info.plist" "${CONTENTS_DIR}/"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
    echo "Icon copied from Resources/AppIcon.icns."
else
    echo "Warning: AppIcon.icns not found in Resources/!"
fi

# 4. Integrate VLCKit, FFmpeg and Plugins
echo "Step 4: Integrating dependencies (VLCKit & FFmpeg)..."
VLC_PATH="/Applications/VLC.app/Contents/MacOS"
cp "${VLC_PATH}/lib/libvlc.dylib" "${FRAMEWORKS_DIR}/"
cp "${VLC_PATH}/lib/libvlccore.dylib" "${FRAMEWORKS_DIR}/"
cp -R "${VLC_PATH}/plugins/" "${PLUGINS_DIR}/"

# Find and copy ffmpeg
FFMPEG_PATH=$(which ffmpeg)
if [ -n "$FFMPEG_PATH" ]; then
    cp "$FFMPEG_PATH" "${MACOS_DIR}/ffmpeg"
    echo "FFmpeg bundled from $FFMPEG_PATH"
else
    echo "Error: ffmpeg not found in PATH!"
    exit 1
fi

# 5. Fix Library Paths and Re-sign
echo "Step 5: Fixing Paths and Re-signing..."
chmod +w "${FRAMEWORKS_DIR}/libvlc.dylib"
chmod +w "${FRAMEWORKS_DIR}/libvlccore.dylib"
install_name_tool -change "@rpath/libvlccore.dylib" "@loader_path/libvlccore.dylib" "${FRAMEWORKS_DIR}/libvlc.dylib" 2>/dev/null
install_name_tool -id "@loader_path/libvlc.dylib" "${FRAMEWORKS_DIR}/libvlc.dylib" 2>/dev/null
install_name_tool -id "@loader_path/libvlccore.dylib" "${FRAMEWORKS_DIR}/libvlccore.dylib" 2>/dev/null
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true

codesign --force --sign - "${FRAMEWORKS_DIR}/libvlccore.dylib"
codesign --force --sign - "${FRAMEWORKS_DIR}/libvlc.dylib"
codesign --force --sign - "${MACOS_DIR}/ffmpeg"
codesign --force --sign - "${MACOS_DIR}/${APP_NAME}"

# Trigger Finder Icon Refresh
touch "${BUNDLE_DIR}"

# 6. Prepare DMG Staging
echo "Step 6: Preparing DMG Staging..."
STAGING_DIR=".build/dmg_staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${BUNDLE_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# 7. Generate Final DMG
echo "Step 7: Generating Professional DMG..."
DMG_NAME="${APP_NAME}-arm64-v1.0.0.dmg"
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_NAME}" > /dev/null

echo "------------------------------------------------"
echo "Success! Directory structure optimized and DMG built."
echo ">> ${DMG_NAME}"
echo "------------------------------------------------"
