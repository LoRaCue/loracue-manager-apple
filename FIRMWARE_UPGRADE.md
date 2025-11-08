# Firmware Upgrade System

## Overview

Enterprise-grade firmware upgrade system with three firmware sources:
1. **GitHub Releases** - Official releases with automatic verification
2. **ZIP Files** - Custom builds with manifest and signature verification
3. **BIN Files** - Raw binaries for advanced users (unsafe)

## Architecture

```
FirmwareUpgradeView (UI)
    ├── GitHub Tab: Release selection + manifest filtering
    ├── ZIP Tab: File picker + verification
    └── BIN Tab: Raw upload with warnings
    
FirmwareUpgradeViewModel (State)
    ├── Release management
    ├── Progress tracking
    └── Error handling
    
Services Layer
    ├── GitHubReleaseService: Fetch releases + manifests
    ├── FirmwareDownloader: ZIP extraction + validation
    ├── FirmwareVerifier: SHA256 + RSA signature
    └── BLEOTAService: Chunked upload via BLE
```

## Security Features

### SHA256 Verification
- All binaries (firmware, bootloader, partition table) verified
- Hash mismatch prevents installation
- Protects against corrupted downloads

### RSA-4096 Signature Verification
- Manifest signed with LoRaCue private key
- Public key embedded in app
- Ensures firmware authenticity
- Only applies to GitHub releases and ZIP files

### Safety Warnings
- BIN files show double confirmation
- Clear warnings about bricking risk
- Advanced users only

## Workflow

### GitHub Release Upgrade

1. **Fetch Releases**
   ```swift
   await viewModel.loadReleases()
   ```
   - Fetches from github.com/LoRaCue/loracue
   - Optional pre-release filtering
   - Displays release list with metadata

2. **Select Release**
   ```swift
   await viewModel.selectRelease(release)
   ```
   - Downloads manifests.json
   - Filters by model/board compatibility
   - Shows available firmware variants

3. **Download & Verify**
   - Downloads ZIP from release assets
   - Extracts firmware binaries
   - Verifies SHA256 hashes
   - Validates RSA signature

4. **Upload**
   - Sends firmware via BLE OTA protocol
   - Chunked transfer (512 bytes)
   - Progress tracking
   - ACK confirmation per chunk

### ZIP File Upgrade

1. **Select ZIP**
   - File picker for .zip files
   - Must contain manifest.json

2. **Extract & Verify**
   - Unzips to temporary directory
   - Parses manifest.json
   - Verifies all binary hashes
   - Validates signature

3. **Upload**
   - Same BLE OTA process as GitHub

### BIN File Upgrade

1. **Safety Warnings**
   - First warning: Unsafe operation
   - Second confirmation: Device restart

2. **Basic Validation**
   - Checks file size (>1KB)
   - Verifies ESP32 magic bytes (0xE9)
   - No signature verification

3. **Upload**
   - Direct BLE OTA upload
   - No additional safety checks

## Progress Tracking

Four stages with visual indicators:

1. **Downloading** (Blue arrow down)
   - Fetching firmware from GitHub
   - Progress: 0-100%

2. **Verifying** (Green shield)
   - SHA256 hash checks
   - RSA signature validation
   - Progress: Indeterminate

3. **Uploading** (Orange arrow up)
   - BLE OTA transfer
   - Progress: 0-100% (chunk-based)

4. **Complete** (Green checkmark)
   - Firmware applied
   - Device will restart

## Error Handling

### Recoverable Errors
- Network failures → Retry button
- Download interruptions → Resume
- Verification failures → Clear error message

### Fatal Errors
- Signature mismatch → Abort with explanation
- Incompatible firmware → Model/board check
- BLE disconnection → Reconnect prompt

### User Feedback
- Clear error messages
- Actionable retry options
- Progress stage indicators
- Completion confirmation

## Manifest Format

```json
{
  "model": "LC-Alpha",
  "board_id": "heltec_v3",
  "board_name": "Heltec LoRa V3",
  "version": "0.2.0-alpha.3",
  "build_date": "2025-11-06",
  "commit": "1944725",
  "target": "esp32s3",
  "flash_size": "8MB",
  "firmware": {
    "file": "firmware.bin",
    "size": 1360112,
    "sha256": "08595e6d...",
    "offset": "0x10000"
  },
  "bootloader": {
    "file": "bootloader.bin",
    "size": 21088,
    "sha256": "b253b6dc...",
    "offset": "0x0"
  },
  "partition_table": {
    "file": "partition-table.bin",
    "size": 3072,
    "sha256": "d5db3029...",
    "offset": "0x8000"
  },
  "esptool_args": [...],
  "signature": "Zj32+weg...",
  "download_url": "https://github.com/..."
}
```

## BLE OTA Protocol

### Command Structure

**Begin Transfer**
```
[0x01] [size: 4 bytes LE]
```

**Data Chunk**
```
[offset: 4 bytes LE] [length: 2 bytes LE] [data: N bytes]
```

**End Transfer**
```
[0x02]
```

### Response
```
[0x06] = ACK
[0x15] = NAK
```

### Chunking
- Chunk size: 512 bytes
- Timeout: 2 seconds per chunk
- Retry: 3 attempts per chunk
- Total timeout: 5 minutes

## Dependencies

- **ZIPFoundation**: ZIP extraction
- **CryptoKit**: SHA256 hashing
- **Security**: RSA signature verification
- **CoreBluetooth**: BLE communication

## Testing

### Manual Testing Checklist

- [ ] GitHub release list loads
- [ ] Pre-release toggle works
- [ ] Manifest filtering by model/board
- [ ] ZIP file extraction
- [ ] SHA256 verification catches corruption
- [ ] Signature verification rejects invalid
- [ ] BIN file shows warnings
- [ ] Progress updates smoothly
- [ ] Error messages are clear
- [ ] Retry functionality works
- [ ] Device restarts after upgrade

### Security Testing

- [ ] Modified firmware rejected
- [ ] Wrong signature rejected
- [ ] Corrupted ZIP rejected
- [ ] Invalid manifest rejected
- [ ] BIN file warnings displayed

## Future Enhancements

- [ ] Automatic update checks
- [ ] Background downloads
- [ ] Rollback on failure
- [ ] Differential updates
- [ ] Multi-device batch updates
- [ ] Update scheduling
- [ ] Changelog display
- [ ] Beta channel support
