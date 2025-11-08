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

// MARK: - General ViewModel

@MainActor
class GeneralViewModel: ObservableObject {
    @Published var config: GeneralConfig?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isDirty = false

    private var originalConfig: GeneralConfig?

    let service: LoRaCueService
    private var cancellables = Set<AnyCancellable>()

    init(service: LoRaCueService) {
        self.service = service

        self.$config
            .dropFirst()
            .sink { [weak self] newConfig in
                self?.isDirty = newConfig != self?.originalConfig
            }
            .store(in: &self.cancellables)
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            let loadedConfig = try await self.service.getGeneral()
            self.config = loadedConfig
            self.originalConfig = loadedConfig
            self.isDirty = false
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        guard let config else { return }
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.setGeneral(config)
            // Reload to get latest data from device
            let reloadedConfig = try await self.service.getGeneral()
            self.config = reloadedConfig
            self.originalConfig = reloadedConfig
            self.isDirty = false
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

// MARK: - Power ViewModel

@MainActor
class PowerViewModel: ObservableObject {
    @Published var config: PowerConfig?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isDirty = false

    private var originalConfig: PowerConfig?
    private var cancellables = Set<AnyCancellable>()

    let service: LoRaCueService

    init(service: LoRaCueService) {
        self.service = service

        self.$config
            .dropFirst()
            .sink { [weak self] newConfig in
                self?.isDirty = newConfig != self?.originalConfig
            }
            .store(in: &self.cancellables)
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            let loadedConfig = try await self.service.getPowerManagement()
            self.config = loadedConfig
            self.originalConfig = loadedConfig
            self.isDirty = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        guard let config else { return }
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.setPowerManagement(config)
            // Reload to get latest data from device
            let reloadedConfig = try await self.service.getPowerManagement()
            self.config = reloadedConfig
            self.originalConfig = reloadedConfig
            self.isDirty = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - LoRa ViewModel

@MainActor
class LoRaViewModel: ObservableObject {
    @Published var config: LoRaConfig?
    @Published var bands: [LoRaBand] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showBandWarning = false
    @Published var isDirty = false

    private var originalConfig: LoRaConfig?
    private var cancellables = Set<AnyCancellable>()

    let service: LoRaCueService

    init(service: LoRaCueService) {
        self.service = service

        self.$config
            .dropFirst()
            .sink { [weak self] newConfig in
                self?.isDirty = newConfig != self?.originalConfig
            }
            .store(in: &self.cancellables)
    }

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            async let configTask = self.service.getLoRa()
            async let bandsTask = self.service.getLoRaBands()

            let loadedConfig = try await configTask
            self.config = loadedConfig
            self.originalConfig = loadedConfig
            self.isDirty = false
            self.bands = try await bandsTask
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        guard let config else { return }
        self.isLoading = true
        defer { isLoading = false }

        do {
            try await self.service.setLoRa(config)
            // Reload to get latest data from device
            let reloadedConfig = try await self.service.getLoRa()
            self.config = reloadedConfig
            self.originalConfig = reloadedConfig
            self.isDirty = false
        } catch {
            self.error = error.localizedDescription
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

struct LoRaPreset {
    let name: String
    let sf: Int
    let bw: Int
    let cr: Int
    let power: Int

    static let presets = [
        LoRaPreset(name: "Conference", sf: 7, bw: 125_000, cr: 5, power: 14),
        LoRaPreset(name: "Auditorium", sf: 9, bw: 125_000, cr: 5, power: 17),
        LoRaPreset(name: "Stadium", sf: 12, bw: 125_000, cr: 8, power: 20)
    ]
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
