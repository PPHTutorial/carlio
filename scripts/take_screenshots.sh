#!/bin/bash

# Flutter App Screenshot Capture Script
# This script automates taking screenshots of the Flutter application

echo "📸 Flutter App Screenshot Capture"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create screenshots directory
mkdir -p screenshots

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Get device list
echo "📱 Available devices:"
flutter devices
echo ""

# Prompt for device selection (optional)
read -p "Enter device ID (press Enter to use default): " device_id

# Build command
if [ -z "$device_id" ]; then
    echo -e "${GREEN}Running screenshot tests on default device...${NC}"
    flutter test integration_test/screenshot_test.dart
else
    echo -e "${GREEN}Running screenshot tests on device: $device_id${NC}"
    flutter test integration_test/screenshot_test.dart --device-id "$device_id"
fi

# Check if screenshots were created
if [ -d "screenshots" ] && [ "$(ls -A screenshots)" ]; then
    echo ""
    echo -e "${GREEN}✅ Screenshots captured successfully!${NC}"
    echo "📁 Location: screenshots/"
    echo ""
    echo "Screenshots:"
    ls -lh screenshots/
else
    echo -e "${YELLOW}⚠️  No screenshots found in screenshots/ directory${NC}"
fi

