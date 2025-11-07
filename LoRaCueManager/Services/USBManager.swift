import Foundation
#if os(macOS)
import IOKit
import IOKit.serial

@MainActor
class USBManager: ObservableObject, DeviceTransport {
    @Published var discoveredDevices: [String] = []
    @Published private var _isConnected = false

    nonisolated var isConnected: Bool {
        MainActor.assumeIsolated {
            self._isConnected
        }
    }

    nonisolated var isReady: Bool {
        MainActor.assumeIsolated {
            self._isConnected
        }
    }

    private var fileDescriptor: Int32 = -1
    private let targetVID: UInt16 = 0x1209
    private let targetPID: UInt16 = 0xFAB0

    func scanForDevices() {
        self.discoveredDevices.removeAll()

        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return
        }

        defer { IOObjectRelease(iterator) }

        var serialService = IOIteratorNext(iterator)
        while serialService != 0 {
            defer {
                IOObjectRelease(serialService)
                serialService = IOIteratorNext(iterator)
            }

            if let path = getDevicePath(serialService),
               isLoRaCueDevice(serialService)
            {
                self.discoveredDevices.append(path)
            }
        }
    }

    func connect(to devicePath: String) throws {
        self.fileDescriptor = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard self.fileDescriptor != -1 else {
            throw USBError.connectionFailed
        }

        var options = termios()
        tcgetattr(self.fileDescriptor, &options)

        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        options.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
        options.c_iflag = tcflag_t(IGNPAR)
        options.c_oflag = 0
        options.c_lflag = 0

        tcsetattr(self.fileDescriptor, TCSANOW, &options)
        self._isConnected = true
    }

    func disconnect() {
        if self.fileDescriptor != -1 {
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        self._isConnected = false
    }

    func sendCommand(_ command: String) async throws -> String {
        guard self.fileDescriptor != -1 else {
            throw USBError.notConnected
        }

        let data = (command + "\n").data(using: .utf8)!
        let written = data.withUnsafeBytes { buffer in
            write(self.fileDescriptor, buffer.baseAddress, buffer.count)
        }

        guard written > 0 else {
            throw USBError.writeFailed
        }

        return try await self.readResponse()
    }

    private func readResponse() async throws -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var response = ""
        let timeout = Date().addingTimeInterval(5.0)

        while Date() < timeout {
            let bytesRead = read(fileDescriptor, &buffer, buffer.count)
            if bytesRead > 0 {
                if let chunk = String(bytes: buffer[..<bytesRead], encoding: .utf8) {
                    response += chunk
                    if response.contains("\n") {
                        return response.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        throw USBError.timeout
    }

    private func getDevicePath(_ service: io_object_t) -> String? {
        let key = "IOCalloutDevice" as CFString
        guard let pathAsCF = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0) else {
            return nil
        }
        return pathAsCF.takeRetainedValue() as? String
    }

    private func isLoRaCueDevice(_ service: io_object_t) -> Bool {
        var parent: io_object_t = 0
        guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(parent) }

        let vidKey = "idVendor" as CFString
        let pidKey = "idProduct" as CFString

        guard let vidCF = IORegistryEntryCreateCFProperty(parent, vidKey, kCFAllocatorDefault, 0),
              let pidCF = IORegistryEntryCreateCFProperty(parent, pidKey, kCFAllocatorDefault, 0)
        else {
            return false
        }

        let vid = (vidCF.takeRetainedValue() as? NSNumber)?.uint16Value ?? 0
        let pid = (pidCF.takeRetainedValue() as? NSNumber)?.uint16Value ?? 0

        return vid == self.targetVID && pid == self.targetPID
    }
}

enum USBError: Error {
    case notConnected
    case connectionFailed
    case writeFailed
    case timeout
}
#endif
