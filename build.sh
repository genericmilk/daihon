#!/usr/bin/env zsh
reset
set -euo pipefail

# cd to repo root (directory of this script)
cd -- "$(cd -- "$(dirname -- "$0")" && pwd)"

CONFIG=debug
RUN=1

usage() {
  echo "Usage: $0 [--release|-r] [--build-only|-b]"
  echo ""
  echo "Options:"
  echo "  --release, -r     Build in release mode, create zip, don't run app"
  echo "  --build-only, -b  Build but don't run the app"
  echo "  --help, -h        Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release|-r)
      CONFIG=release
      RUN=0  # Don't run the app in release mode
      ;;
    --build-only|-b)
      RUN=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: swift toolchain not found in PATH" >&2
  exit 1
fi

close_existing_daihon() {
  echo "==> Checking for existing Daihon instances"
  
  # Find and kill any running Daihon processes
  local PIDS
  PIDS=$(pgrep -f "DaihonApp" 2>/dev/null || pgrep -f "Daihon\.app" 2>/dev/null || true)
  
  if [[ -n "$PIDS" ]]; then
    echo "==> Found running Daihon instances, closing them..."
    echo "$PIDS" | while read -r PID; do
      if [[ -n "$PID" ]]; then
        echo "    Closing process $PID"
        kill "$PID" 2>/dev/null || true
      fi
    done
    
    # Wait a moment for graceful shutdown
    sleep 2
    
    # Force kill if still running
    PIDS=$(pgrep -f "DaihonApp" 2>/dev/null || pgrep -f "Daihon\.app" 2>/dev/null || true)
    if [[ -n "$PIDS" ]]; then
      echo "==> Force closing remaining instances..."
      echo "$PIDS" | while read -r PID; do
        if [[ -n "$PID" ]]; then
          echo "    Force closing process $PID"
          kill -9 "$PID" 2>/dev/null || true
        fi
      done
    fi
  else
    echo "==> No existing Daihon instances found"
  fi
}

ensure_app_icon() {
  local RES_DIR="Sources/DaihonApp/Resources"
  local ICON_DIR="AppIcon.icon"
  mkdir -p "$RES_DIR"

  # If AppIcon.png or Daihon.icns already exists in resources, keep it
  if [[ -f "$RES_DIR/AppIcon.png" || -f "$RES_DIR/Daihon.icns" ]]; then
    return 0
  fi

  if [[ -d "$ICON_DIR" ]]; then
    # Prefer any PNGs inside Daihon.icon (pick the largest by pixel area)
    local -a PNGS
    IFS=$'\n' PNGS=($(find "$ICON_DIR" -type f -iname '*.png' 2>/dev/null)) || true
    if [[ ${#PNGS[@]} -gt 0 ]]; then
      local BEST=""
      local BEST_AREA=0
      for p in "${PNGS[@]}"; do
        local W H AREA
        W=$(sips -g pixelWidth "$p" 2>/dev/null | awk '/pixelWidth/ {print $2}') || true
        H=$(sips -g pixelHeight "$p" 2>/dev/null | awk '/pixelHeight/ {print $2}') || true
        if [[ -n "$W" && -n "$H" ]]; then
          AREA=$((W*H))
          if (( AREA > BEST_AREA )); then
            BEST_AREA=$AREA
            BEST="$p"
          fi
        fi
      done
      if [[ -n "$BEST" ]]; then
        cp -f "$BEST" "$RES_DIR/AppIcon.png"
        echo "==> Using app icon: $BEST -> $RES_DIR/AppIcon.png"
        return 0
      fi
    fi

    # Or use any .icns if available
    local ICNS
    ICNS=$(find "$ICON_DIR" -type f -iname '*.icns' -print -quit 2>/dev/null || true)
    if [[ -n "$ICNS" ]]; then
      cp -f "$ICNS" "$RES_DIR/Daihon.icns"
      echo "==> Using app icon: $ICNS -> $RES_DIR/Daihon.icns"
      return 0
    fi
  fi

  # Informative notice if only SVG exists
  if [[ -d "$ICON_DIR" ]] && find "$ICON_DIR" -type f -iname '*.svg' -print -quit >/dev/null; then
    echo "[icon] Found SVG(s) in $ICON_DIR. Converting to PNG for app icon."
    local SVG
    SVG=$(find "$ICON_DIR" -type f -iname '*.svg' -print -quit 2>/dev/null || true)
    if [[ -n "$SVG" ]]; then
      qlmanage -t -s 1024 -o "$RES_DIR" "$SVG" >/dev/null 2>&1 || true
      local PNG_OUT="$RES_DIR/$(basename "$SVG").png"
      if [[ -f "$PNG_OUT" ]]; then
        mv "$PNG_OUT" "$RES_DIR/AppIcon.png"
        echo "==> Using app icon: $SVG -> $RES_DIR/AppIcon.png"
        return 0
      fi
    fi
    echo "[icon] Failed to convert SVG. Please export a PNG (512px or 1024px) or .icns."
    echo "[icon] See: https://developer.apple.com/documentation/xcode/configuring-your-app-icon"
  fi
}

ensure_app_icon

close_existing_daihon

# Clean up existing app bundle for release builds
if [[ "$CONFIG" == "release" ]]; then
  if [[ -d "Daihon.app" ]]; then
    echo "==> Removing existing Daihon.app for release build"
    rm -rf "Daihon.app"
  fi
  if [[ -f "Daihon.zip" ]]; then
    echo "==> Removing existing Daihon.zip"
    rm -f "Daihon.zip"
  fi
fi

echo "==> Building (configuration: $CONFIG)"
swift build -c "$CONFIG"

# Always create app bundle for proper icon support and distribution
echo "==> Creating app bundle"
APP_DIR="Daihon.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Copy executable
cp ".build/$CONFIG/DaihonApp" "$MACOS_DIR/"
chmod +x "$MACOS_DIR/DaihonApp"

# Copy resources
cp -r "Sources/DaihonApp/Resources/"* "$RES_DIR/" 2>/dev/null || true

# Copy custom menu bar icon
if [[ -f "icon-res/foreground.png" ]]; then
  cp "icon-res/foreground.png" "$RES_DIR/"
  echo "==> Copied custom menu bar icon: icon-res/foreground.png -> $RES_DIR/"
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>DaihonApp</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon.icon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.genericmilk.daihon</string>
	<key>CFBundleName</key>
	<string>Daihon</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2025 genericmilk. All rights reserved.</string>
</dict>
</plist>
EOF

if [[ "$CONFIG" == "release" ]]; then
  echo "==> Creating release DMG: Daihon.dmg"

  DMG_WINDOW_BASE_SIZE=1024
  DMG_WINDOW_TARGET_SIZE=800
  DMG_WINDOW_LEFT=100
  DMG_WINDOW_TOP=100
  DMG_WINDOW_RIGHT=$((DMG_WINDOW_LEFT + DMG_WINDOW_TARGET_SIZE))
  DMG_WINDOW_BOTTOM=$((DMG_WINDOW_TOP + DMG_WINDOW_TARGET_SIZE))
  DMG_ICON_BASE_SIZE=256
  DMG_ICON_TARGET_SIZE=$((DMG_ICON_BASE_SIZE / 2))
  DMG_POSITION_SCALE_NUM=$DMG_WINDOW_TARGET_SIZE
  DMG_POSITION_SCALE_DEN=$DMG_WINDOW_BASE_SIZE

  scale_dmg_coord() {
    local value=$1
    echo $(( (value * DMG_POSITION_SCALE_NUM + DMG_POSITION_SCALE_DEN / 2) / DMG_POSITION_SCALE_DEN ))
  }

  DAIHON_ICON_X=$(scale_dmg_coord 280)
  DAIHON_ICON_Y=$(scale_dmg_coord 512)
  APPLICATIONS_ICON_X=$(scale_dmg_coord 748)
  APPLICATIONS_ICON_Y=$(scale_dmg_coord 512)

  # Create temporary directory for DMG contents
  DMG_TEMP_DIR=$(mktemp -d)
  DMG_NAME="Daihon"
  DMG_FILE="${DMG_NAME}.dmg"
  
  # Clean up existing DMG
  if [[ -f "$DMG_FILE" ]]; then
    echo "==> Removing existing $DMG_FILE"
    rm -f "$DMG_FILE"
  fi
  
  # Copy app to temp directory
  cp -R "$APP_DIR" "$DMG_TEMP_DIR/"
  
  # Create Applications symlink
  ln -s /Applications "$DMG_TEMP_DIR/Applications"
  
  # Create temporary DMG
  TEMP_DMG="${DMG_NAME}_temp.dmg"
  hdiutil create -srcfolder "$DMG_TEMP_DIR" -volname "$DMG_NAME" -fs HFS+ \
    -format UDRW -size 150m "$TEMP_DMG"
  
  # Mount the temporary DMG
  echo "==> Mounting temporary DMG for configuration"
  MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" 2>&1)
  MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -E '/dev/disk[0-9]+s[0-9]+' | tail -1 | awk '{print $3}')
  
  if [[ -z "$MOUNT_DIR" ]]; then
    echo "Error: Failed to mount temporary DMG"
    echo "Mount output: $MOUNT_OUTPUT"
    rm -f "$TEMP_DMG"
    rm -rf "$DMG_TEMP_DIR"
    exit 1
  fi
  
  echo "==> DMG mounted at: $MOUNT_DIR"
  
  echo "==> Configuring DMG layout"
  
  # Set background image
  if [[ -f "icon-res/dmg.png" ]]; then
    mkdir -p "$MOUNT_DIR/.background"
    cp "icon-res/dmg.png" "$MOUNT_DIR/.background/background.png"
    if command -v sips >/dev/null 2>&1; then
      sips -Z "$DMG_WINDOW_TARGET_SIZE" "$MOUNT_DIR/.background/background.png" >/dev/null || true
    fi
    echo "==> Background image copied to DMG"
  else
    echo "Warning: Background image not found at icon-res/dmg.png"
  fi
  
  # Configure Finder view settings using AppleScript
  echo "==> Applying DMG layout and background"
  osascript <<EOF
tell application "Finder"
    tell disk "$DMG_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {$DMG_WINDOW_LEFT, $DMG_WINDOW_TOP, $DMG_WINDOW_RIGHT, $DMG_WINDOW_BOTTOM}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $DMG_ICON_TARGET_SIZE
        
        -- Set background image
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Wait a moment for the view to update
        delay 1
        
        -- Position items according to coordinates
        set position of item "Daihon.app" of container window to {$DAIHON_ICON_X, $DAIHON_ICON_Y}
        set position of item "Applications" of container window to {$APPLICATIONS_ICON_X, $APPLICATIONS_ICON_Y}
        
        -- Update and close
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
  
  # Set custom icon for the volume (using app icon)
  if [[ -f "$MOUNT_DIR/Daihon.app/Contents/Resources/AppIcon.icns" ]]; then
    cp "$MOUNT_DIR/Daihon.app/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  fi
  
  # Hide background folder
  SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
  
  # Sync and unmount
  sync
  hdiutil detach "$MOUNT_DIR"
  
  # Convert to compressed read-only DMG
  hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FILE"
  
  # Clean up
  rm -f "$TEMP_DMG"
  rm -rf "$DMG_TEMP_DIR"
  
  echo "==> Release build complete: $DMG_FILE created"
  
  # Also create zip for compatibility
  echo "==> Creating release zip: Daihon.zip"
  zip -r "Daihon.zip" "$APP_DIR" >/dev/null 2>&1
  echo "==> Release zip created: Daihon.zip"
elif [[ "$RUN" -eq 1 ]]; then
  echo "==> Running Daihon.app (configuration: $CONFIG)"
  # exec replaces the shell so Ctrl-C stops the app and exits the script
  exec open "$APP_DIR"
else
  echo "==> Build complete (skipping run)"
fi
