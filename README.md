# Daihon

A SwiftUI macOS menu bar app to manage npm scripts per project.

Features
- Menu bar popover lists projects and their npm scripts
- Start/Stop scripts in the background (zsh + npm run <script>)
- Live tailing logs per running script
- Preferences to add projects (auto-detects scripts from package.json)
 - Persistent logs: output is saved while running even if the log window is closed or the script is restarted

Requirements
- macOS 13+
- Xcode 15+ or Swift 5.9 toolchain
- Node.js/npm installed and on PATH for zsh

Build & Run (SwiftPM)
```
swift build
swift run DaihonApp
```

Usage
- Click the tray icon to open the popover.
- Add projects via Preferences; scripts are detected from package.json.
- Start a script; its menu shows Stop and Logs while running.
- Logs opens a window streaming the process output.

Notes
- Environment: The app launches zsh with `-lc`, which loads your shell init and PATH.
- Persistence: Projects are saved to `~/Library/Application Support/Daihon/projects.json`.
 - Logs: Per-script logs are saved under `~/Library/Application Support/Daihon/Logs/<projectID>/<scriptID>.log`. Use the "Clear" button in the Logs window to truncate.
