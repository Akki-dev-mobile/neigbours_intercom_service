#!/bin/bash

# OneGate Flutter App Installation Script for MIUI Devices
# This script handles the common MIUI installation restrictions

echo "🔧 OneGate MIUI Installation Helper"
echo "=================================="

# Check if device is connected
echo "📱 Checking device connection..."
DEVICE_COUNT=$(adb devices | grep -c "device$")
if [ $DEVICE_COUNT -eq 0 ]; then
    echo "❌ No Android device connected. Please connect your device and enable USB debugging."
    exit 1
fi

echo "✅ Device connected: $(adb devices | grep device | head -1 | cut -f1)"

# Check if it's a MIUI device
MIUI_VERSION=$(adb shell getprop ro.miui.ui.version.name 2>/dev/null)
if [ -n "$MIUI_VERSION" ]; then
    echo "📱 MIUI Version detected: $MIUI_VERSION"
    echo "⚠️  MIUI devices require special configuration. Please ensure:"
    echo "   1. 'Install via USB' is enabled in Developer options"
    echo "   2. 'Turn off MIUI optimization' is enabled (requires reboot)"
    echo "   3. Security app allows 'Install unknown apps' for Package installer"
    echo ""
    read -p "Have you configured these settings? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Please configure MIUI settings first, then run this script again."
        exit 1
    fi
fi

# Reset ADB connection
echo "🔄 Resetting ADB connection..."
adb kill-server
sleep 2
adb start-server
sleep 2

# Check if APK exists
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "📦 Building debug APK..."
    flutter build apk --debug
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build APK"
        exit 1
    fi
fi

echo "📦 APK found: $APK_PATH"

# Try multiple installation methods
echo "🚀 Attempting installation..."

# Method 1: Standard install with user flag
echo "Method 1: Standard install with user flag..."
adb install --user 0 "$APK_PATH"
if [ $? -eq 0 ]; then
    echo "✅ Installation successful!"
    exit 0
fi

# Method 2: Install with replace and downgrade flags
echo "Method 2: Install with replace and downgrade flags..."
adb install -r -d "$APK_PATH"
if [ $? -eq 0 ]; then
    echo "✅ Installation successful!"
    exit 0
fi

# Method 3: Uninstall first, then install
echo "Method 3: Uninstall existing app first..."
adb uninstall com.cubeonebiz.gate.flutter_onegate 2>/dev/null
sleep 2
adb install "$APK_PATH"
if [ $? -eq 0 ]; then
    echo "✅ Installation successful!"
    exit 0
fi

# Method 4: Push APK and install via shell
echo "Method 4: Push APK to device and install via shell..."
adb push "$APK_PATH" /data/local/tmp/app-debug.apk
adb shell pm install -r /data/local/tmp/app-debug.apk
if [ $? -eq 0 ]; then
    echo "✅ Installation successful!"
    adb shell rm /data/local/tmp/app-debug.apk
    exit 0
fi

echo "❌ All installation methods failed."
echo "📋 Troubleshooting steps:"
echo "   1. Ensure 'Install via USB' is enabled in Developer options"
echo "   2. Disable 'Turn off MIUI optimization' and reboot device"
echo "   3. Check Security app → Install unknown apps permissions"
echo "   4. Try installing manually by copying APK to device"
echo ""
echo "💡 Manual installation:"
echo "   1. Copy $APK_PATH to your device storage"
echo "   2. Use a file manager to install the APK"
echo "   3. Allow installation when prompted"

exit 1
