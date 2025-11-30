import Combine
import Foundation
import SwiftUI

// MARK: - Device List ViewModel

@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var favorites: Set<String> = []
    @Published var isScanning = false

    let service: LoRaCueService
    private var cancellables = Set<AnyCancellable>()

    init(service: LoRaCueService) {
        self.service = service
    }

    func startScanning() {
        self.isScanning = true
    }

    func stopScanning() {
        self.isScanning = false
    }

    func toggleFavorite(_ deviceId: String) {
        if self.favorites.contains(deviceId) {
            self.favorites.remove(deviceId)
        } else {
            self.favorites.insert(deviceId)
        }
    }
}

// MARK: - Base Config ViewModel

@MainActor
class ConfigViewModel<T: Codable & Equatable>: ObservableObject {
    @Published var config: T?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isDirty = false

    var originalConfig: T?
    let service: LoRaCueService
    var cancellables = Set<AnyCancellable>()

    init(service: LoRaCueService) {
        self.service = service
    }

    func setupBindings() {
        self.$config
            .dropFirst()
            .sink { [weak self] newConfig in
                self?.isDirty = newConfig != self?.originalConfig
            }
            .store(in: &self.cancellables)
    }

    func load(_ fetch: () async throws -> T) async {
        self.isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await fetch()
            self.config = loaded
            self.originalConfig = loaded
            self.isDirty = false
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(_ persist: (T) async throws -> Void, reload: () async throws -> T) async {
        guard let config else { return }
        self.isLoading = true
        defer { isLoading = false }
        do {
            try await persist(config)
            let reloaded = try await reload()
            self.config = reloaded
            self.originalConfig = reloaded
            self.isDirty = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - General ViewModel

@MainActor
class GeneralViewModel: ConfigViewModel<GeneralConfig> {
    override init(service: LoRaCueService) {
        super.init(service: service)
        self.setupBindings()
    }

    func load() async {
        await super.load { try await self.service.getGeneral() }
    }

    func save() async {
        await super.save {
            try await self.service.setGeneral($0)
        } reload: {
            try await self.service.getGeneral()
        }
    }

    func factoryReset() async {
        self.isLoading = true
        defer { isLoading = false }
        do {
            try await self.service.factoryReset()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Power ViewModel

@MainActor
class PowerViewModel: ConfigViewModel<PowerConfig> {
    override init(service: LoRaCueService) {
        super.init(service: service)
        self.setupBindings()
    }

    func load() async {
        await super.load { try await self.service.getPowerManagement() }
    }

    func save() async {
        await super.save {
            try await self.service.setPowerManagement($0)
        }
        reload: {
            try await self.service.getPowerManagement()
        }
    }
}

// MARK: - LoRa ViewModel

@MainActor
class LoRaViewModel: ConfigViewModel<LoRaConfig> {
    @Published var bands: [LoRaBand] = []
    @Published var presets: [LoRaPreset] = []
    @Published var showBandWarning = false

    override init(service: LoRaCueService) {
        super.init(service: service)
        self.setupBindings()
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            async let configTask = self.service.getLoRa()
            async let bandsTask = self.service.getLoRaBands()
            async let presetsTask = self.service.getLoRaPresets()

            let loadedConfig = try await configTask
            self.config = loadedConfig
            self.originalConfig = loadedConfig
            self.isDirty = false
            self.error = nil

            self.bands = try await bandsTask
            self.presets = await (try? presetsTask) ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        await super.save {
            try await self.service.setLoRa($0)
        } reload: {
            try await self.service.getLoRa()
        }
    }

    func applyPreset(_ preset: LoRaPreset) {
        self.config?.spreadingFactor = preset.sf
        self.config?.bandwidth = preset.bw
        self.config?.codingRate = preset.cr
        self.config?.txPower = preset.power
    }

    var performance: (latency: Int, range: Int) {
        guard let config else { return (0, 0) }
        return LoRaCalculator.calculatePerformance(
            sf: config.spreadingFactor,
            bw: config.bandwidth,
            cr: config.codingRate,
            txPower: config.txPower
        )
    }
}

struct LoRaPreset: Codable, Identifiable {
    let name: String
    let description: String?
    let sf: Int
    let bw: Int
    let cr: Int
    let power: Int

    var id: String { self.name }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case sf = "spreading_factor"
        case bw = "bandwidth_khz"
        case cr = "coding_rate"
        case power = "tx_power_dbm"
    }
}

// MARK: - Paired Devices ViewModel

@MainActor
class PairedDevicesViewModel: ObservableObject {
    @Published var devices: [PairedDevice] = []
    @Published var isLoading = false
    @Published var error: String?

    let service: LoRaCueService

    init(service: LoRaCueService) {
        self.service = service
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            self.devices = try await self.service.getPairedDevices()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func add(_ device: PairedDevice) async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.addPairedDevice(device)
            await self.load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func update(_ device: PairedDevice) async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.updatePairedDevice(device)
            await self.load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(mac: String) async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.deletePairedDevice(mac: mac)
            await self.load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Firmware ViewModel

@MainActor
class FirmwareViewModel: ObservableObject {
    @Published var selectedFile: URL?
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false
    @Published var error: String?

    let service: LoRaCueService

    init(service: LoRaCueService) {
        self.service = service
    }

    func startUpgrade() async {
        guard let url = selectedFile else { return }
        self.isUploading = true
        defer { isUploading = false }

        do {
            let data = try Data(contentsOf: url)
            try await service.upgradeFirmware(size: data.count)
            // TODO: Implement actual firmware data transfer
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - System ViewModel

@MainActor
class SystemViewModel: ObservableObject {
    @Published var deviceInfo: DeviceInfo?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showResetConfirmation = false

    let service: LoRaCueService

    init(service: LoRaCueService) {
        self.service = service
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            self.deviceInfo = try await self.service.getDeviceInfo()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func factoryReset() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.factoryReset()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
