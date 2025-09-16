#!/usr/bin/env zsh
reset
set -euo pipefail

# cd to repo root (directory of this script)
cd -- "$(cd -- "$(dirname -- "$0")" && pwd)"

CONFIG=debug
RUN=1

usage() {
  echo "Usage: $0 [--release|-r] [--build-only|-b]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release|-r)
      CONFIG=release
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

echo "==> Building (configuration: $CONFIG)"
swift build -c "$CONFIG"

if [[ "$RUN" -eq 1 ]]; then
  echo "==> Creating app bundle for proper icon support"
  local APP_DIR="Daihon.app"
  local CONTENTS_DIR="$APP_DIR/Contents"
  local MACOS_DIR="$CONTENTS_DIR/MacOS"
  local RES_DIR="$CONTENTS_DIR/Resources"
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
  
  echo "==> Running Daihon.app (configuration: $CONFIG)"
  # exec replaces the shell so Ctrl-C stops the app and exits the script
  exec open "$APP_DIR"
else
  echo "==> Build complete (skipping run)"
fi
