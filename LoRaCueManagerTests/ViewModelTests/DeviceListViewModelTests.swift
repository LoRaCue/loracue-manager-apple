import XCTest

@testable import LoRaCueManager

@MainActor
final class DeviceListViewModelTests: XCTestCase {
    var sut: DeviceListViewModel!
    var mockBLE: MockBLEManager!
    var mockUSB: MockUSBManager!

    override func setUp() {
        super.setUp()
        self.mockBLE = MockBLEManager()
        self.mockUSB = MockUSBManager()
        self.sut = DeviceListViewModel(bleManager: self.mockBLE, usbManager: self.mockUSB)
    }

    func testStartScanning() {
        self.sut.startScanning()
        XCTAssertTrue(self.mockBLE.isScanning)
        XCTAssertTrue(self.sut.isScanning)
    }

    func testStopScanning() {
        self.sut.startScanning()
        self.sut.stopScanning()
        XCTAssertFalse(self.mockBLE.isScanning)
        XCTAssertFalse(self.sut.isScanning)
    }

    func testToggleFavorite() {
        let device = DiscoveredDevice(id: "test", name: "Test", type: .ble, rssi: -50)
        self.sut.toggleFavorite(device)
        XCTAssertTrue(self.sut.favorites.contains("test"))
        self.sut.toggleFavorite(device)
        XCTAssertFalse(self.sut.favorites.contains("test"))
    }
}

class MockBLEManager: BLEManagerProtocol {
    var isScanning = false
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevice: CBPeripheral?
    var isDeviceConnected = false

    func startScanning() { self.isScanning = true }
    func stopScanning() { self.isScanning = false }
    func connect(to device: DiscoveredDevice) async throws {}
    func disconnect() {}
    func sendCommand(_ command: String) async throws -> String { "" }
}

class MockUSBManager: USBManagerProtocol {
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevice: io_object_t = 0
    var isDeviceConnected = false

    func startScanning() {}
    func stopScanning() {}
    func connect(to device: DiscoveredDevice) async throws {}
    func disconnect() {}
    func sendCommand(_ command: String) async throws -> String { "" }
}
