# Screenshot Capture Guide

This guide explains how to capture screenshots of the Car Collection app UI/UX screens.

## Prerequisites

- Flutter SDK installed
- A connected device or emulator
- `integration_test` package (already added to `dev_dependencies`)

## Quick Start

### Option 1: Using Flutter Test (Recommended)

```bash
flutter test integration_test/screenshot_test.dart
```

### Option 2: Using Shell Script (Linux/Mac)

```bash
chmod +x scripts/take_screenshots.sh
./scripts/take_screenshots.sh
```

### Option 3: Using Batch Script (Windows)

```bash
scripts\take_screenshots.bat
```

### Option 4: Specify a Device

```bash
flutter test integration_test/screenshot_test.dart --device-id <device-id>
```

To list available devices:
```bash
flutter devices
```

## What Screenshots Are Captured?

The script automatically captures the following screenshots:

1. **01_dashboard_light.png** - Dashboard screen in light theme
2. **02_dashboard_dark.png** - Dashboard screen in dark theme
3. **03_garage_dark.png** - Garage screen in dark theme
4. **04_garage_light.png** - Garage screen in light theme
5. **05_car_detail_light.png** - Car detail screen in light theme
6. **06_car_detail_scrolled_light.png** - Car detail screen scrolled down
7. **07_image_preview.png** - Image preview screen with zoom
8. **08_dashboard_featured_dark.png** - Dashboard with featured collection in dark theme

## Output Location

All screenshots are saved to the `screenshots/` directory in the project root.

```
carcollection/
  └── screenshots/
      ├── 01_dashboard_light.png
      ├── 02_dashboard_dark.png
      ├── 03_garage_dark.png
      └── ...
```

## Customization

To modify which screenshots are captured, edit `integration_test/screenshot_test.dart`:

- Add new screenshots by calling `_takeScreenshot()`
- Modify navigation logic to capture different states
- Adjust wait times if screens load slowly

## Troubleshooting

### Screenshots not capturing
- Ensure the device/emulator is connected: `flutter devices`
- Wait for the app to fully load before capturing
- Check that the app has data loaded (cars in the collection)

### Navigation failing
- Increase wait times in `pumpAndSettle()` calls
- Verify that the app UI elements exist before tapping
- Check console output for error messages

### Empty screenshots
- Ensure the app has loaded data (cars in cache or scraped)
- Wait longer for images to load
- Check that the screen is visible before capturing

## Notes

- Screenshots are captured in PNG format
- The script automatically navigates through the app
- Theme switching is done automatically
- The script waits for UI animations to complete

## For CI/CD

If using in CI/CD, ensure:
- A device/emulator is running or configured
- Sufficient time is allocated for screenshots
- Screenshots directory is persisted as an artifact

Example GitHub Actions:
```yaml
- name: Capture screenshots
  run: flutter test integration_test/screenshot_test.dart

- name: Upload screenshots
  uses: actions/upload-artifact@v3
  with:
    name: screenshots
    path: screenshots/
```

