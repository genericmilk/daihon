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

ensure_app_icon() {
  local RES_DIR="Sources/DaihonApp/Resources"
  local ICON_DIR="Daihon.icon"
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
    echo "[icon] Found SVG(s) in $ICON_DIR but no PNG/.icns. Please export a PNG (512px or 1024px) or .icns."
    echo "[icon] See: https://developer.apple.com/documentation/xcode/configuring-your-app-icon"
  fi
}

ensure_app_icon

echo "==> Building (configuration: $CONFIG)"
swift build -c "$CONFIG"

if [[ "$RUN" -eq 1 ]]; then
  echo "==> Running DaihonApp (configuration: $CONFIG)"
  # exec replaces the shell so Ctrl-C stops the app and exits the script
  exec swift run -c "$CONFIG" DaihonApp
else
  echo "==> Build complete (skipping run)"
fi
