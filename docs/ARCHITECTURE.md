# LoRaCue Manager Architecture

Comprehensive technical documentation for maintainers and advanced contributors.

## Table of Contents

- [Overview](#overview)
- [Architecture Pattern](#architecture-pattern)
- [Project Structure](#project-structure)
- [Cross-Platform Implementation](#cross-platform-implementation)
- [Core Components](#core-components)
- [Testing Strategy](#testing-strategy)
- [Build Configuration](#build-configuration)
- [Enterprise Features](#enterprise-features)

---

## Overview

LoRaCue Manager is a cross-platform Swift application supporting iOS 17.0+, iPadOS 17.0+, and macOS 14.0+ with a single codebase. Built using SwiftUI and modern Swift concurrency, it follows MVVM architecture with protocol-based dependency injection.

### Technology Stack

- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **State Management**: Combine + @Published
- **Concurrency**: async/await + @MainActor
- **Dependency Injection**: Protocol-based
- **Testing**: XCTest + XCUITest
- **Documentation**: DocC
- **Code Quality**: SwiftLint + SwiftFormat

---

## Architecture Pattern

### MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────┐
│                    View Layer                    │
│  (SwiftUI Views - DeviceListView, ConfigView)   │
└────────────────┬────────────────────────────────┘
                 │ @ObservedObject
                 ↓
┌─────────────────────────────────────────────────┐
│                 ViewModel Layer                  │
│  (DeviceListViewModel, ConfigurationViewModel)  │
│  • @Published properties                         │
│  • Business logic                                │
│  • State management                              │
└────────────────┬────────────────────────────────┘
                 │ Protocol-based
                 ↓
┌─────────────────────────────────────────────────┐
│                  Service Layer                   │
│  (BLEManager, USBManager, LoRaCueService)       │
│  • Device communication                          │
│  • Data persistence                              │
│  • Network operations                            │
└────────────────┬────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────┐
│                   Model Layer                    │
│  (DeviceInfo, Configuration, LoRaSettings)      │
│  • Data structures                               │
│  • Codable conformance                           │
└─────────────────────────────────────────────────┘
```

### Key Principles

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Testability**: Protocol-based injection enables mocking
3. **Reactive Updates**: Combine publishers propagate state changes
4. **Thread Safety**: @MainActor ensures UI updates on main thread

---

## Project Structure

```
LoRaCueManager/
├── LoRaCueManager.xcworkspace/          # 👈 ALWAYS open this
│   └── contents.xcworkspacedata
│
├── LoRaCueManager.xcodeproj/            # Main app project
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/
│
├── LoRaCueManager/                      # App source
│   ├── LoRaCueManagerApp.swift          # @main entry point
│   ├── Info-macOS.plist                 # macOS metadata
│   ├── LoRaCueManager.entitlements      # Capabilities
│   ├── LoRaCueManager.xctestplan       # Test plan
│   │
│   ├── Assets.xcassets/                 # Images & colors
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   │
│   ├── Models/                          # Data models
│   │   └── Models.swift
│   │
│   ├── Services/                        # Business logic
│   │   ├── BLEManager.swift             # Bluetooth LE
│   │   ├── USBManager.swift             # USB (macOS)
│   │   ├── LoRaCueService.swift         # Device protocol
│   │   └── Protocols.swift              # DI protocols
│   │
│   ├── ViewModels/                      # MVVM layer
│   │   └── ViewModels.swift
│   │
│   ├── Views/                           # SwiftUI UI
│   │   ├── ContentView.swift
│   │   ├── DeviceListView.swift
│   │   ├── DeviceDetailView.swift
│   │   ├── GeneralView.swift
│   │   ├── PowerView.swift
│   │   ├── LoRaView.swift
│   │   ├── FirmwareUpgradeView.swift
│   │   ├── SystemView.swift
│   │   └── PairedDevicesView.swift
│   │
│   ├── Utils/                           # Helpers
│   │   ├── Logger.swift                 # OSLog wrapper
│   │   ├── Errors.swift                 # Error types
│   │   ├── Localization.swift           # i18n helper
│   │   └── LoRaCalculator.swift         # LoRa math
│   │
│   └── Resources/                       # Localization
│       └── en.lproj/
│           └── Localizable.strings
│
├── LoRaCueManagerTests/                 # Unit tests
│   ├── ViewModelTests/
│   │   ├── DeviceListViewModelTests.swift
│   │   └── ConfigurationViewModelTests.swift
│   └── ServiceTests/
│       └── BLEManagerTests.swift
│
├── LoRaCueManagerUITests/               # UI tests
│   └── DeviceFlowUITests.swift
│
├── Config/                              # Build config
│   ├── Shared.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── Tests.xcconfig
│
├── Scripts/                             # Git hooks
│   ├── validate-commit-msg.sh
│   ├── pre-commit-checks.sh
│   ├── pre-push-checks.sh
│   └── setup-hooks.sh
│
├── .swiftlint.yml                       # Linter config
├── .swiftformat                         # Formatter config
├── .gitignore                           # Git exclusions
├── Makefile                             # Build automation
├── README.md                            # User docs
├── CONTRIBUTING.md                      # Dev guide
└── docs/
    └── ARCHITECTURE.md                  # This file
```

---

## Cross-Platform Implementation

### Supported Platforms

| Platform | Version | Navigation | Bluetooth | USB |
|----------|---------|------------|-----------|-----|
| iOS | 17.0+ | TabView | ✅ | ❌ |
| iPadOS | 17.0+ | TabView | ✅ | ❌ |
| macOS | 14.0+ | NavigationSplitView | ✅ | ✅ |

### Build Configuration

**Shared.xcconfig**:
```
SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator
SDKROOT = auto
MACOSX_DEPLOYMENT_TARGET = 14.0
IPHONEOS_DEPLOYMENT_TARGET = 17.0
TARGETED_DEVICE_FAMILY = 1,2  // iPhone and iPad
```

### Platform-Specific Code

**Conditional Compilation**:
```swift
#if os(macOS)
// macOS-only: USB manager, Settings window
@StateObject private var usbManager = USBManager()

Settings {
    SettingsView()
}
#endif

#if os(iOS)
// iOS-only: TabView navigation
TabView {
    DeviceListView()
    ConfigurationView()
}
#endif
```

**UI Adaptation**:
```swift
#if os(iOS)
var body: some View {
    TabView {
        // Compact navigation for iPhone/iPad
    }
}
#else
var body: some View {
    NavigationSplitView {
        // Sidebar navigation for macOS
    }
}
#endif
```

### Entitlements

**iOS/iPadOS**:
- `com.apple.security.app-sandbox`
- `com.apple.security.device.bluetooth`

**macOS (Additional)**:
- `com.apple.security.device.usb`
- `com.apple.security.files.user-selected.read-write`

---

## Core Components

### 1. BLEManager

**Purpose**: Manages Bluetooth Low Energy device discovery and communication.

**Key Features**:
- Device scanning with RSSI filtering
- Connection management
- Characteristic discovery
- Data read/write operations

**Protocol**: `BLEManagerProtocol` for dependency injection

**Usage**:
```swift
let bleManager = BLEManager()
bleManager.startScanning()
bleManager.connect(to: peripheral)
```

### 2. USBManager (macOS only)

**Purpose**: Manages USB-CDC serial device communication.

**Key Features**:
- IOKit-based device enumeration
- Serial port communication
- Automatic device detection

**Protocol**: `USBManagerProtocol` for dependency injection

### 3. LoRaCueService

**Purpose**: High-level device protocol implementation.

**Key Features**:
- Command/response protocol
- Configuration management
- Firmware update coordination

**Protocol**: `LoRaCueServiceProtocol` for dependency injection

**Device Protocol**:
```
Command:  GET_INFO\n
Response: {"board_id":"loracue","version":"1.0.0"}\n

Command:  GET_CONFIG general\n
Response: {"name":"LoRaCue-001","mode":"tx"}\n

Command:  SET_CONFIG general {"name":"NewName"}\n
Response: {"status":"ok"}\n
```

### 4. ViewModels

**DeviceListViewModel**:
- Manages device list state
- Handles scanning operations
- Manages favorites

**ConfigurationViewModel**:
- Loads/saves device configuration
- Validates input
- Handles errors

**State Management**:
```swift
@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var favorites: Set<String> = []
    @Published var isScanning = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(service: LoRaCueService) {
        // Combine publisher forwarding
        service.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
```

---

## Testing Strategy

### Unit Tests

**Coverage Target**: 80%+ for ViewModels and Services

**Mock Implementation**:
```swift
class MockBLEManager: BLEManagerProtocol {
    var discoveredDevices: [CBPeripheral] = []
    var isScanning = false
    
    func startScanning() {
        isScanning = true
    }
}
```

**Test Structure**:
```swift
@MainActor
final class DeviceListViewModelTests: XCTestCase {
    var viewModel: DeviceListViewModel!
    var mockService: MockLoRaCueService!
    var mockBLEManager: MockBLEManager!
    
    override func setUp() {
        mockBLEManager = MockBLEManager()
        mockService = MockLoRaCueService(bleManager: mockBLEManager)
        viewModel = DeviceListViewModel(service: mockService)
    }
    
    func testScanningToggle() {
        viewModel.toggleScanning()
        XCTAssertTrue(mockBLEManager.isScanning)
    }
}
```

### UI Tests

**Critical Flows**:
- Device scanning
- Device connection
- Configuration navigation
- Firmware update flow

**Example**:
```swift
func testScanForDevices() {
    let app = XCUIApplication()
    app.launch()
    
    let scanButton = app.buttons["Scan for devices"]
    if scanButton.exists {
        scanButton.tap()
        XCTAssertTrue(app.buttons["Stop scanning"].waitForExistence(timeout: 2))
    }
}
```

### Running Tests

```bash
# All tests
make test

# Unit tests only
xcodebuild test -scheme LoRaCueManager \
  -destination 'platform=macOS' \
  -only-testing:LoRaCueManagerTests

# UI tests only
xcodebuild test -scheme LoRaCueManager \
  -destination 'platform=macOS' \
  -only-testing:LoRaCueManagerUITests

# With code coverage
xcodebuild test -scheme LoRaCueManager \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES
```

---

## Build Configuration

### XCConfig Files

**Shared.xcconfig** - Common settings:
```
PRODUCT_BUNDLE_IDENTIFIER = com.loracue.manager
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
```

**Debug.xcconfig** - Development:
```
SWIFT_OPTIMIZATION_LEVEL = -Onone
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
```

**Release.xcconfig** - Production:
```
SWIFT_OPTIMIZATION_LEVEL = -O
SWIFT_COMPILATION_MODE = wholemodule
```

### Info.plist Strategy

**macOS**: Uses `Info-macOS.plist` file
**iOS/iPadOS**: Auto-generated with `INFOPLIST_KEY_*` settings

**Required Keys**:
```
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription = "Connect to LoRaCue devices"
INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities"
```

### Building

```bash
# iOS Simulator
make build-ios

# macOS
make build-macos

# Clean
make clean
```

---

## Enterprise Features

### 1. Logging

**OSLog Integration**:
```swift
import OSLog

extension Logger {
    static let ble = Logger(subsystem: "com.loracue.manager", category: "ble")
    static let service = Logger(subsystem: "com.loracue.manager", category: "service")
}

// Usage
Logger.ble.info("Device connected: \(deviceName)")
Logger.service.error("Command failed: \(error.localizedDescription)")
```

### 2. Error Handling

**Comprehensive Error Types**:
```swift
enum LoRaCueError: LocalizedError {
    case connectionFailed
    case commandTimeout
    case invalidResponse
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "error.connection_failed".localized
        case .commandTimeout: return "error.command_timeout".localized
        // ...
        }
    }
}
```

### 3. Accessibility

**VoiceOver Support**:
```swift
Button("Scan") {
    toggleScanning()
}
.accessibilityLabel(isScanning ? "Stop scanning" : "Scan for devices")
.accessibilityHint(isScanning ? "Stops searching" : "Searches for nearby devices")
```

### 4. Localization

**50+ Localized Strings**:
```swift
// Localizable.strings
"devices.title" = "Devices";
"devices.scan" = "Scan";
"error.connection_failed" = "Connection failed";

// Usage
Text("devices.title".localized)
```

### 5. Documentation

**DocC Comments**:
```swift
/// Manages Bluetooth Low Energy device discovery and communication.
///
/// Use `BLEManager` to scan for nearby LoRaCue devices and establish connections.
///
/// ## Topics
/// ### Scanning
/// - ``startScanning()``
/// - ``stopScanning()``
///
/// ### Connection
/// - ``connect(to:)``
/// - ``disconnect()``
public class BLEManager: NSObject, ObservableObject {
    // ...
}
```

### 6. Code Quality

**SwiftLint Configuration**:
- Line length: 120 characters
- Custom rules: no_print, sorted_imports
- Opt-in rules: empty_count, explicit_init

**SwiftFormat Configuration**:
- 4 spaces indentation
- 120 character line limit
- Sorted imports

### 7. Git Hooks

**Pre-commit**: SwiftLint + SwiftFormat + actionlint
**Commit-msg**: Conventional commits validation
**Pre-push**: Build validation (macOS + iOS)

---

## Performance Considerations

### Async/Await

```swift
func loadConfiguration() async throws -> Configuration {
    let data = try await service.sendCommand("GET_CONFIG general")
    return try JSONDecoder().decode(Configuration.self, from: data)
}
```

### @MainActor

```swift
@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    
    func updateDevices() {
        // Guaranteed to run on main thread
        devices = fetchDevices()
    }
}
```

### Combine Publishers

```swift
service.objectWillChange
    .sink { [weak self] in
        self?.objectWillChange.send()
    }
    .store(in: &cancellables)
```

---

## Security

### Sandboxing

All platforms use App Sandbox with minimal entitlements:
- Bluetooth device access
- USB device access (macOS only)
- User-selected file access

### Permissions

Clear usage descriptions for all sensitive permissions:
- Bluetooth: "Connect to LoRaCue devices via Bluetooth"
- USB: "Connect to LoRaCue devices via USB"

---

## Distribution

### App Store

**iOS/iPadOS**:
1. Archive build in Xcode
2. Upload to App Store Connect
3. Submit for review

**macOS**:
1. Archive build in Xcode
2. Notarize with Apple
3. Upload to App Store Connect or distribute directly

### GitHub Releases

Automated via `.github/workflows/release.yml`:
- Triggered by version tags (v1.0.0)
- Builds iOS and macOS archives
- Creates GitHub Release with downloadable apps

---

## Troubleshooting

### Build Issues

**"Missing package product"**: Remove and re-add package dependencies
**"Code signing failed"**: Check entitlements and provisioning profiles
**"Bluetooth unauthorized"**: Add usage description to Info.plist

### Runtime Issues

**Bluetooth not working**: Check entitlements and Info.plist keys
**USB not detected**: macOS only, check IOKit permissions
**UI not updating**: Ensure @MainActor on ViewModels

---

## Future Enhancements

- [ ] watchOS support
- [ ] tvOS support
- [ ] Widget extension
- [ ] Shortcuts integration
- [ ] CloudKit sync
- [ ] Advanced analytics
- [ ] Crash reporting integration

---

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
- [DocC Documentation](https://developer.apple.com/documentation/docc)
