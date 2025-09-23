<div align="center">

<img src="build/AppIcon.iconset/icon_128x128@2x.png" alt="Daihon Icon" width="128" height="128">

# Daihon

**A powerful macOS menu bar app for managing and running development scripts across projects**

[![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-success?style=flat-square)](https://github.com/genericmilk/daihon)
[![Version](https://img.shields.io/badge/Version-1.0-brightgreen?style=flat-square)](https://github.com/genericmilk/daihon/releases)

</div>

## 🚀 Features

- **Menu Bar Integration**: Clean, minimal interface that lives in your macOS menu bar
- **Project Management**: Organize and manage multiple development projects
- **Script Execution**: Run development scripts with real-time output monitoring
- **Package Manager Support**: Works with npm, yarn, pnpm, and other package managers
- **Live Output**: Stream command output with separate stdout and stderr handling
- **Preferences**: Customizable settings for package managers and project configurations
- **Notifications**: Get notified when long-running scripts complete

## 📥 Installation

### Option 1: Download from Releases (Recommended)

1. Go to the [Releases page](https://github.com/genericmilk/daihon/releases)
2. Download the latest `Daihon.dmg` file
3. Mount the dmg image
4. Move `Daihon.app` to your Applications folder
5. **Important**: Run the following command to whitelist the app (required for unsigned apps):
   ```bash
   xattr -c /Applications/Daihon.app
   ```
6. Launch Daihon from Applications or Spotlight

### Option 2: Build from Source

#### Prerequisites

- macOS 13.0 or later
- Xcode 14.0 or later with Swift 5.9+
- Command line tools: `xcode-select --install`

#### Build Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/genericmilk/daihon.git
   cd daihon
   ```

2. **Build and run (debug mode)**:
   ```bash
   ./build.sh
   ```
   This will build the app and automatically launch it.

3. **Build release version**:
   ```bash
   ./build.sh --release
   ```
   This creates `Daihon.zip` ready for distribution.

4. **Build without running**:
   ```bash
   ./build.sh --build-only
   ```

#### Build Script Options

- `--release` or `-r`: Build in release mode and create a zip file
- `--build-only` or `-b`: Build but don't run the app
- `--help` or `-h`: Show help message

## 🎯 Usage

1. **Launch Daihon**: After installation, Daihon appears as an icon in your menu bar
2. **Add Projects**: Click the menu bar icon and add your development projects
3. **Configure Scripts**: Set up scripts for each project (build, test, dev server, etc.)
4. **Run Scripts**: Execute scripts directly from the menu bar with live output
5. **Monitor Progress**: View real-time output and get notifications when complete

### Setting up Projects

1. Click the Daihon menu bar icon
2. Select "Add Project" or open Preferences
3. Choose your project directory
4. Add custom scripts or let Daihon detect common scripts from `package.json`
5. Configure your preferred package manager (npm, yarn, pnpm)

## ⚙️ Requirements

- **Operating System**: macOS 13.0 (Ventura) or later
- **Architecture**: Intel x64 or Apple Silicon (Universal support)
- **Memory**: 50MB RAM
- **Disk Space**: 10MB

## 🔧 Configuration

Daihon stores its configuration in `~/Library/Application Support/Daihon/`. You can customize:

- Default package manager
- Project locations and scripts
- Notification preferences
- UI appearance settings

## 🛡️ Security Notice

**Important for macOS users**: Since Daihon is currently unsigned, macOS Gatekeeper will prevent it from running. After downloading, you must run:

```bash
xattr -c /path/to/Daihon.app
```

This removes the quarantine attribute and allows the app to run. We're working on code signing for future releases.

## 🐛 Troubleshooting

### Common Issues

**App won't launch after download**:
```bash
# Remove quarantine attribute
xattr -c /Applications/Daihon.app

# If that doesn't work, try:
sudo spctl --master-disable
# Then re-enable after testing: sudo spctl --master-enable
```

**Build errors**:
```bash
# Ensure you have the latest Xcode command line tools
xcode-select --install

# Clean and rebuild
swift package clean
./build.sh
```

**Permission issues**:
```bash
# Make build script executable
chmod +x build.sh
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**genericmilk**
- GitHub: [@genericmilk](https://github.com/genericmilk)

## 🙏 Acknowledgments

- Built with Swift and SwiftUI
- Icons and design inspired by macOS Human Interface Guidelines
- Thanks to the Swift community for excellent tooling and resources

---

<div align="center">

**[⬆ Back to Top](#daihon)**

Made with ❤️ for the macOS development community

</div>
