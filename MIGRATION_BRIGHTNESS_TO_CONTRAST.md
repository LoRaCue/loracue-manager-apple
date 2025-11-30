# Migration Guide: Brightness → Contrast Rename

## Overview
This breaking change renames all "brightness" fields to "contrast" to accurately reflect their function (OLED/E-Paper contrast control, not backlight brightness).

## Changes Made

### 1. Model Layer (`Models.swift`)
- **GeneralConfig.brightness** → **GeneralConfig.contrast**
- **CodingKeys.brightness** → **CodingKeys.contrast**

### 2. Mock Data (`MockTransport.swift`)
- Updated mock response: `"brightness":128` → `"contrast":128`

### 3. UI Layer (`GeneralView.swift`)
- Section title: "Display Brightness" → "Display Contrast"
- All property bindings updated to use `config.contrast`

## API Changes

### Before
```json
{
  "method": "general:get",
  "result": {
    "name": "LoRaCue-Device",
    "mode": "presenter",
    "brightness": 128,
    "bluetooth": true,
    "slot_id": 1
  }
}
```

### After
```json
{
  "method": "general:get",
  "result": {
    "name": "LoRaCue-Device",
    "mode": "presenter",
    "contrast": 128,
    "bluetooth": true,
    "slot_id": 1
  }
}
```

## Compatibility

- **Value Range**: Unchanged (0-255)
- **Firmware Requirement**: Requires firmware with contrast field support
- **Breaking Change**: Yes - old firmware with "brightness" field will fail to parse

## Testing Checklist

- [x] Model decoding with new field name
- [x] Model encoding with new field name
- [x] UI displays correct label
- [x] UI slider binds to correct property
- [x] Mock transport returns correct field
- [x] Build succeeds on macOS
- [ ] Build succeeds on iOS
- [ ] Test with actual device running new firmware

## Future Considerations

This change prepares for future backlight brightness support on E-Paper displays, which will be a separate field from contrast control.
