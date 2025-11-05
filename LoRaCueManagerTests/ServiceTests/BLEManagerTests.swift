import CoreBluetooth
import XCTest

@testable import LoRaCueManager

final class BLEManagerTests: XCTestCase {
    var sut: BLEManager!

    override func setUp() {
        super.setUp()
        self.sut = BLEManager()
    }

    func testInitialState() {
        XCTAssertFalse(self.sut.isScanning)
        XCTAssertFalse(self.sut.isDeviceConnected)
        XCTAssertTrue(self.sut.discoveredDevices.isEmpty)
    }

    func testStartScanning() {
        self.sut.startScanning()
        XCTAssertTrue(self.sut.isScanning)
    }

    func testStopScanning() {
        self.sut.startScanning()
        self.sut.stopScanning()
        XCTAssertFalse(self.sut.isScanning)
    }

    func testDisconnect() {
        self.sut.disconnect()
        XCTAssertFalse(self.sut.isDeviceConnected)
        XCTAssertNil(self.sut.connectedDevice)
    }
}
