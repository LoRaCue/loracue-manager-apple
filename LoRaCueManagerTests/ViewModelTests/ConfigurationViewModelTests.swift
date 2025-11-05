import XCTest

@testable import LoRaCueManager

@MainActor
final class ConfigurationViewModelTests: XCTestCase {
    var sut: GeneralViewModel!
    var mockService: MockLoRaCueService!

    override func setUp() {
        super.setUp()
        self.mockService = MockLoRaCueService()
        self.sut = GeneralViewModel(service: self.mockService)
    }

    func testLoadConfiguration() async throws {
        self.mockService.configToReturn = GeneralConfig(
            name: "Test",
            mode: "tx",
            brightness: 50,
            bluetooth: true,
            slotId: 1
        )

        try await self.sut.loadConfig()
        XCTAssertEqual(self.sut.config?.name, "Test")
        XCTAssertFalse(self.sut.isLoading)
    }

    func testSaveConfiguration() async throws {
        self.sut.config = GeneralConfig(
            name: "Updated",
            mode: "rx",
            brightness: 75,
            bluetooth: true,
            slotId: 2
        )

        try await self.sut.saveConfig()
        XCTAssertEqual(self.mockService.lastSavedConfig?.name, "Updated")
    }
}

class MockLoRaCueService: LoRaCueServiceProtocol {
    var configToReturn: GeneralConfig?
    var lastSavedConfig: GeneralConfig?

    func getGeneralConfig() async throws -> GeneralConfig {
        guard let config = configToReturn else { throw AppError.deviceNotConnected }
        return config
    }

    func setGeneralConfig(_ config: GeneralConfig) async throws {
        self.lastSavedConfig = config
    }

    func getPowerConfig() async throws -> PowerConfig {
        throw AppError.deviceNotConnected
    }

    func getLoRaConfig() async throws -> LoRaConfig {
        throw AppError.deviceNotConnected
    }

    func factoryReset() async throws {}
}
