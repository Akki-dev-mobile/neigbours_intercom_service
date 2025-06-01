#!/bin/bash

# OneGate Flutter App Runner for MIUI Devices
# This script handles running the app after manual installation

echo "🚀 OneGate MIUI App Runner"
echo "========================="

# Check if device is connected
echo "📱 Checking device connection..."
DEVICE_COUNT=$(adb devices | grep -c "device$")
if [ $DEVICE_COUNT -eq 0 ]; then
    echo "❌ No Android device connected. Please connect your device and enable USB debugging."
    exit 1
fi

echo "✅ Device connected: $(adb devices | grep device | head -1 | cut -f1)"

# Check if app is installed
echo "🔍 Checking if OneGate app is installed..."
APP_INSTALLED=$(adb shell pm list packages | grep "com.cubeonebiz.gate.flutter_onegate")
if [ -z "$APP_INSTALLED" ]; then
    echo "❌ OneGate app is not installed."
    echo "📋 Please install the app manually:"
    echo "   1. Open File Manager on your device"
    echo "   2. Go to Downloads folder"
    echo "   3. Tap on 'onegate-debug.apk'"
    echo "   4. Follow installation prompts"
    echo "   5. Run this script again after installation"
    exit 1
fi

echo "✅ OneGate app is installed!"

# Launch the app
echo "🚀 Launching OneGate app..."
adb shell am start -n com.cubeonebiz.gate.flutter_onegate/com.cubeonebiz.gate.flutter_onegate.MainActivity

if [ $? -eq 0 ]; then
    echo "✅ OneGate app launched successfully!"
    echo "📱 Check your device screen - the app should be running."
    
    # Enable hot reload for development
    echo "🔥 Setting up hot reload..."
    echo "   You can now use 'flutter attach' to connect for hot reload"
    echo "   Or use 'r' to hot reload, 'R' to hot restart in this terminal"
    
    # Optional: Start flutter attach automatically
    read -p "Do you want to start flutter attach for hot reload? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔗 Starting flutter attach..."
        flutter attach
    fi
else
    echo "❌ Failed to launch OneGate app"
    echo "📋 Troubleshooting:"
    echo "   1. Make sure the app is properly installed"
    echo "   2. Check if the app appears in your device's app drawer"
    echo "   3. Try launching the app manually from the device"
fi
