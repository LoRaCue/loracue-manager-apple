# LoRaCue Device Protocol Reference

## Overview

LoRaCue devices communicate using **JSON-RPC 2.0** over BLE (Nordic UART Service) or USB-CDC Serial.

- **Transport:** Newline-delimited JSON (`\n`)
- **Encoding:** UTF-8
- **Standard:** [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)

## Transport Layer

### BLE (Nordic UART Service)

- **Service UUID:** `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX Characteristic:** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` (write)
- **RX Characteristic:** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` (notify)
- **MTU:** 20-512 bytes (negotiated)
- **Chunking:** Large responses may arrive in multiple notifications

### USB-CDC Serial (macOS only)

- **Baud Rate:** 460800
- **Data Bits:** 8
- **Parity:** None
- **Stop Bits:** 1

## JSON-RPC 2.0 Format

### Request

```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": { /* optional parameters */ },
  "id": 1
}
```

### Successful Response

```json
{
  "jsonrpc": "2.0",
  "result": { /* result data or "ok" */ },
  "id": 1
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  },
  "id": 1
}
```

## Standard Error Codes

| Code | Message | Meaning |
|------|---------|---------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Missing required fields |
| -32601 | Method not found | Unknown method |
| -32602 | Invalid params | Invalid parameter values |
| -32603 | Internal error | Device internal error |

## Methods

### Device Information

#### `device:info`

Get device hardware and firmware information.

> **Legacy:** Previously `GET_DEVICE_INFO` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"device:info","id":1}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "board_id": "loracue",
    "version": "1.0.0",
    "commit": "abc1234",
    "branch": "main",
    "build_date": "2025-11-05",
    "chip_model": "ESP32-S3",
    "chip_revision": 0,
    "cpu_cores": 2,
    "flash_size_mb": 8,
    "mac": "aa:bb:cc:dd:ee:ff",
    "uptime_sec": 3600,
    "free_heap_kb": 128,
    "partition": "ota_0"
  },
  "id": 1
}
```

#### `ping`

Check device connectivity.

> **Legacy:** Previously `PING` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"ping","id":1}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "pong",
  "id": 1
}
```

### General Configuration

#### `general:get`

Get general device settings.

> **Legacy:** Previously `GET_GENERAL` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"general:get","id":2}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "name": "LoRaCue-001",
    "mode": "PRESENTER",
    "brightness": 128,
    "slot_id": 1,
    "bluetooth": true
  },
  "id": 2
}
```

#### `general:set`

Update general device settings.

> **Legacy:** Previously `SET_GENERAL` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "general:set",
  "params": {
    "name": "LoRaCue-001",
    "mode": "PRESENTER",
    "brightness": 128,
    "slot_id": 1,
    "bluetooth": true
  },
  "id": 3
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 3
}
```

**Parameters:**

- `name` (string, max 32 chars): Device name
- `mode` (string): `"PRESENTER"` or `"PC"`
- `brightness` (int, 0-255): Display brightness
- `slot_id` (int, 1-16): Multi-PC routing slot
- `bluetooth` (bool): Bluetooth enabled

### Power Management

#### `power:get`

Get power management settings.

> **Legacy:** Previously `GET_POWER_MANAGEMENT` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"power:get","id":4}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "display_sleep_enabled": true,
    "display_sleep_timeout_ms": 30000,
    "light_sleep_enabled": true,
    "light_sleep_timeout_ms": 60000,
    "deep_sleep_enabled": false,
    "deep_sleep_timeout_ms": 300000
  },
  "id": 4
}
```

#### `power:set`

Update power management settings.

> **Legacy:** Previously `SET_POWER_MANAGEMENT` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "power:set",
  "params": {
    "display_sleep_enabled": true,
    "display_sleep_timeout_ms": 30000,
    "light_sleep_enabled": true,
    "light_sleep_timeout_ms": 60000,
    "deep_sleep_enabled": false,
    "deep_sleep_timeout_ms": 300000
  },
  "id": 5
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 5
}
```

**Parameters:**

- `display_sleep_enabled` (bool): Enable display sleep
- `display_sleep_timeout_ms` (int): Display sleep timeout in milliseconds
- `light_sleep_enabled` (bool): Enable light sleep mode
- `light_sleep_timeout_ms` (int): Light sleep timeout in milliseconds
- `deep_sleep_enabled` (bool): Enable deep sleep mode
- `deep_sleep_timeout_ms` (int): Deep sleep timeout in milliseconds

### LoRa Configuration

#### `lora:get`

Get LoRa radio configuration.

> **Legacy:** Previously `GET_LORA` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"lora:get","id":6}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "band_id": "HW_433",
    "frequency": 433000,
    "spreading_factor": 7,
    "bandwidth": 500,
    "coding_rate": 5,
    "tx_power": 20
  },
  "id": 6
}
```

#### `lora:set`

Update LoRa radio configuration.

> **Legacy:** Previously `SET_LORA` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "lora:set",
  "params": {
    "band_id": "HW_433",
    "frequency": 433000,
    "spreading_factor": 7,
    "bandwidth": 500,
    "coding_rate": 5,
    "tx_power": 20
  },
  "id": 7
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 7
}
```

**Parameters:**

- `band_id` (string): Band identifier
- `frequency` (int, kHz): Center frequency
- `spreading_factor` (int, 7-12): LoRa SF
- `bandwidth` (int, kHz): 125, 250, or 500
- `coding_rate` (int, 5-8): LoRa CR (4/5 to 4/8)
- `tx_power` (int, dBm): Transmit power

#### `lora:bands`

Get available LoRa frequency bands.

> **Legacy:** Previously `GET_LORA_BANDS` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"lora:bands","id":8}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": [
    {
      "id": "HW_433",
      "name": "433/470 MHz Band",
      "center_khz": 433000,
      "min_khz": 430000,
      "max_khz": 440000,
      "max_power_dbm": 10
    }
  ],
  "id": 8
}
```

#### `lora:key:get`

Get LoRa encryption key.

> **Legacy:** Previously `GET_LORA_KEY` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"lora:key:get","id":9}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "aes_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "id": 9
}
```

#### `lora:key:set`

Update LoRa encryption key.

> **Legacy:** Previously `SET_LORA_KEY` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "lora:key:set",
  "params": {
    "aes_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "id": 10
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 10
}
```

**Parameters:**

- `aes_key` (string): 64 hex characters representing 32-byte AES-256 key

### Device Pairing

#### `paired:list`

Get list of paired devices.

> **Legacy:** Previously `GET_PAIRED_DEVICES` in text protocol

**Request:**

```json
{"jsonrpc":"2.0","method":"paired:list","id":11}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": [
    {
      "name": "Device-001",
      "mac": "aa:bb:cc:dd:ee:ff",
      "aes_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  ],
  "id": 11
}
}
```

#### `paired:add`

Pair a new device.

> **Legacy:** Previously `PAIR_DEVICE` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "paired:add",
  "params": {
    "name": "Device-001",
    "mac": "aa:bb:cc:dd:ee:ff",
    "aes_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "id": 12
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 12
}
```

**Parameters:**

- `name` (string): Device name
- `mac` (string): MAC address in format `aa:bb:cc:dd:ee:ff`
- `aes_key` (string): 64 hex characters representing 32-byte AES-256 key

#### `paired:update`

Update paired device information.

> **Legacy:** Previously `UPDATE_PAIRED_DEVICE` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "paired:update",
  "params": {
    "mac": "aa:bb:cc:dd:ee:ff",
    "name": "New Name",
    "aes_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "id": 13
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 13
}
```

**Parameters:**

- `mac` (string): MAC address of device to update
- `name` (string): New device name
- `aes_key` (string): 64 hex characters representing 32-byte AES-256 key

#### `paired:delete`

Remove a paired device.

> **Legacy:** Previously `UNPAIR_DEVICE` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "paired:delete",
  "params": {
    "mac": "aa:bb:cc:dd:ee:ff"
  },
  "id": 14
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 14
}
```

### System Operations

#### `device:reset`

Reset device to factory defaults.

> **Legacy:** Previously `FACTORY_RESET` in text protocol (not yet implemented in firmware)

**Request:**

```json
{"jsonrpc":"2.0","method":"device:reset","id":15}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ok",
  "id": 15
}
```

**Note:** Device will reboot after reset.

#### `firmware:upgrade`

Initiate firmware upgrade (OTA).

> **Legacy:** Previously `FIRMWARE_UPGRADE` in text protocol

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "firmware:upgrade",
  "params": {
    "size": 1048576
  },
  "id": 16
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": "ready",
  "id": 16
}
```

**Note:** After this response, send raw firmware binary data. Device will respond with progress updates.

## Migration from Legacy Protocol

### Legacy Format (Deprecated)

```
→ GET_GENERAL\n
← {"name":"LC-One",...}\n

→ SET_GENERAL {"name":"New"}\n
← OK Device config updated\n
```

### JSON-RPC Format (Current)

```
→ {"jsonrpc":"2.0","method":"general:get","id":1}\n
← {"jsonrpc":"2.0","result":{"name":"LC-One",...},"id":1}\n

→ {"jsonrpc":"2.0","method":"general:set","params":{"name":"New"},"id":2}\n
← {"jsonrpc":"2.0","result":"ok","id":2}\n
```

### Migration Timeline

1. **Phase 1:** Firmware supports both protocols (auto-detect)
2. **Phase 2:** App migrates to JSON-RPC
3. **Phase 3:** Remove legacy protocol support

## Implementation Notes

### Request ID Management

- Client generates unique IDs (incrementing integers recommended)
- Server echoes ID in response for correlation
- IDs can be reused after response received

### Error Handling

- Always check for `error` field in response
- Display `error.message` to user
- Log `error.code` for debugging

### Timeout Handling

- Recommended timeout: 5 seconds per request
- Retry logic: 3 attempts with exponential backoff
- Cancel pending requests on disconnect

### Chunked Responses

- BLE may split large responses across multiple notifications
- Buffer until complete JSON object received
- Validate JSON before parsing

## Examples

### Complete Session

```json
→ {"jsonrpc":"2.0","method":"ping","id":1}
← {"jsonrpc":"2.0","result":"pong","id":1}

→ {"jsonrpc":"2.0","method":"device:info","id":2}
← {"jsonrpc":"2.0","result":{"board_id":"loracue",...},"id":2}

→ {"jsonrpc":"2.0","method":"general:get","id":3}
← {"jsonrpc":"2.0","result":{"name":"LC-One",...},"id":3}

→ {"jsonrpc":"2.0","method":"general:set","params":{"brightness":200},"id":4}
← {"jsonrpc":"2.0","result":"ok","id":4}
```

### Error Example

```json
→ {"jsonrpc":"2.0","method":"invalid_method","id":5}
← {"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":5}

→ {"jsonrpc":"2.0","method":"general:set","params":{"mode":"INVALID"},"id":6}
← {"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid mode (must be PRESENTER or PC)"},"id":6}
```

→ {"jsonrpc":"2.0","method":"set_general","params":{"mode":"INVALID"},"id":6}
← {"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid mode (must be PRESENTER or PC)"},"id":6}
```

## Version History

- **v2.0.0** (2025-11-05): JSON-RPC 2.0 protocol
- **v1.0.0** (2024): Legacy text-based protocol (deprecated)
