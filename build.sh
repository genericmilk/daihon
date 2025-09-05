#!/usr/bin/env zsh
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

echo "==> Building (configuration: $CONFIG)"
swift build -c "$CONFIG"

if [[ "$RUN" -eq 1 ]]; then
  echo "==> Running DaihonApp (configuration: $CONFIG)"
  # exec replaces the shell so Ctrl-C stops the app and exits the script
  exec swift run -c "$CONFIG" DaihonApp
else
  echo "==> Build complete (skipping run)"
fi
