# LoRaCue Manager

A modern cross-platform application for managing LoRaCue devices via Bluetooth Low Energy and USB connectivity.

[![CI](https://github.com/LoRaCue/loracue-manager-apple/actions/workflows/ci.yml/badge.svg)](https://github.com/LoRaCue/loracue-manager-apple/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- 🔵 **Bluetooth LE** - Wireless device management
- 🔌 **USB-CDC Serial** - Direct wired connection (macOS only)
- 📱 **Cross-Platform** - iOS, iPadOS, and macOS support
- ⚙️ **Device Configuration** - General, power, and LoRa radio settings
- 🔄 **Firmware Updates** - Over-the-air firmware upgrades
- 💾 **Favorites** - Quick access to frequently used devices
- 🌐 **Localized** - Multi-language support ready

## Platform Support

| Platform | Version | Features |
|----------|---------|----------|
| **iOS** | 17.0+ | Bluetooth, Touch UI, iPhone/iPad layouts |
| **iPadOS** | 17.0+ | Bluetooth, Touch UI, Split view |
| **macOS** | 14.0+ | Bluetooth, USB, Sidebar navigation, Menu bar |

## Quick Start

### Requirements
- macOS 14.0+ (for development)
- Xcode 15.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/LoRaCue/loracue-manager-apple.git
   cd loracue-manager-apple
   ```

2. **Open in Xcode**
   ```bash
   open LoRaCueManager.xcworkspace
   ```

3. **Build and Run**
   - Select target device (Mac, iPhone Simulator, or iPad Simulator)
   - Press ⌘R to build and run

### Development Setup

For contributors, see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed setup instructions including git hooks and code quality tools.

## Usage

### Connecting to a Device

1. **Bluetooth**: Tap "Scan" to discover nearby LoRaCue devices
2. **USB** (macOS only): Connect device via USB cable - auto-detected
3. Select device from list to connect

### Configuration

Navigate through tabs to configure:
- **General**: Device name, mode, brightness
- **Power**: Sleep timeout settings
- **LoRa**: Radio parameters (frequency, spreading factor, bandwidth)
- **Firmware**: Update device firmware
- **System**: Factory reset and system operations

## Architecture

Built with modern Swift and SwiftUI:
- **MVVM Pattern** - Clean separation of concerns
- **Combine** - Reactive state management
- **Protocols** - Dependency injection for testability
- **DocC** - Comprehensive API documentation

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Device Protocol

LoRaCue devices communicate via ASCII commands with JSON responses:

```
Command:  GET_INFO\n
Response: {"board_id":"loracue","version":"1.0.0",...}\n

Command:  GET_CONFIG general\n
Response: {"name":"LoRaCue-001","mode":"tx",...}\n

Command:  SET_CONFIG general {"name":"NewName"}\n
Response: {"status":"ok"}\n
```

All commands are newline-terminated. Responses are single-line JSON objects.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup and workflow
- Code style guidelines
- Commit message conventions
- Pull request process

## Testing

```bash
# Run all tests
make test

# Run linter
make lint

# Format code
make format
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/LoRaCue/loracue-manager-apple/issues)
- **Documentation**: See inline DocC comments and [docs/](docs/)

## Acknowledgments

Built with modern Apple technologies:
- SwiftUI for declarative UI
- CoreBluetooth for BLE connectivity
- IOKit for USB communication (macOS)
- Combine for reactive programming
