#!/bin/bash

# Generate Onegate Launcher Icons from onegate.png
# This script generates all required icon sizes for Android and iOS

set -e

SOURCE_IMAGE="assets/media/images/onegate.png"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image not found: $SOURCE_IMAGE"
    exit 1
fi

echo "Generating launcher icons from $SOURCE_IMAGE..."

# Android Adaptive Icon Foregrounds (safe area: 66% of 108dp)
# We'll use the full icon centered in a 108dp canvas
ANDROID_FOREGROUND_SIZES=(
    "108:drawable-mdpi/ic_launcher_foreground.png"
    "162:drawable-hdpi/ic_launcher_foreground.png"
    "216:drawable-xhdpi/ic_launcher_foreground.png"
    "324:drawable-xxhdpi/ic_launcher_foreground.png"
    "432:drawable-xxxhdpi/ic_launcher_foreground.png"
)

# Android Legacy Icons
ANDROID_LEGACY_SIZES=(
    "48:mipmap-mdpi/ic_launcher.png"
    "72:mipmap-hdpi/ic_launcher.png"
    "96:mipmap-xhdpi/ic_launcher.png"
    "144:mipmap-xxhdpi/ic_launcher.png"
    "192:mipmap-xxxhdpi/ic_launcher.png"
)

# iOS Icon Sizes (unique sizes from Contents.json - using numbered filenames)
# Note: Some sizes appear multiple times but use the same filename
IOS_SIZES=(
    "1024:ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"
    "512:ios/Runner/Assets.xcassets/AppIcon.appiconset/512.png"
    "256:ios/Runner/Assets.xcassets/AppIcon.appiconset/256.png"
    "216:ios/Runner/Assets.xcassets/AppIcon.appiconset/216.png"
    "196:ios/Runner/Assets.xcassets/AppIcon.appiconset/196.png"
    "180:ios/Runner/Assets.xcassets/AppIcon.appiconset/180.png"
    "172:ios/Runner/Assets.xcassets/AppIcon.appiconset/172.png"
    "167:ios/Runner/Assets.xcassets/AppIcon.appiconset/167.png"
    "152:ios/Runner/Assets.xcassets/AppIcon.appiconset/152.png"
    "144:ios/Runner/Assets.xcassets/AppIcon.appiconset/144.png"
    "120:ios/Runner/Assets.xcassets/AppIcon.appiconset/120.png"
    "114:ios/Runner/Assets.xcassets/AppIcon.appiconset/114.png"
    "102:ios/Runner/Assets.xcassets/AppIcon.appiconset/102.png"
    "100:ios/Runner/Assets.xcassets/AppIcon.appiconset/100.png"
    "92:ios/Runner/Assets.xcassets/AppIcon.appiconset/92.png"
    "88:ios/Runner/Assets.xcassets/AppIcon.appiconset/88.png"
    "87:ios/Runner/Assets.xcassets/AppIcon.appiconset/87.png"
    "80:ios/Runner/Assets.xcassets/AppIcon.appiconset/80.png"
    "76:ios/Runner/Assets.xcassets/AppIcon.appiconset/76.png"
    "72:ios/Runner/Assets.xcassets/AppIcon.appiconset/72.png"
    "66:ios/Runner/Assets.xcassets/AppIcon.appiconset/66.png"
    "64:ios/Runner/Assets.xcassets/AppIcon.appiconset/64.png"
    "60:ios/Runner/Assets.xcassets/AppIcon.appiconset/60.png"
    "58:ios/Runner/Assets.xcassets/AppIcon.appiconset/58.png"
    "57:ios/Runner/Assets.xcassets/AppIcon.appiconset/57.png"
    "55:ios/Runner/Assets.xcassets/AppIcon.appiconset/55.png"
    "50:ios/Runner/Assets.xcassets/AppIcon.appiconset/50.png"
    "48:ios/Runner/Assets.xcassets/AppIcon.appiconset/48.png"
    "40:ios/Runner/Assets.xcassets/AppIcon.appiconset/40.png"
    "32:ios/Runner/Assets.xcassets/AppIcon.appiconset/32.png"
    "29:ios/Runner/Assets.xcassets/AppIcon.appiconset/29.png"
    "20:ios/Runner/Assets.xcassets/AppIcon.appiconset/20.png"
    "16:ios/Runner/Assets.xcassets/AppIcon.appiconset/16.png"
    "128:ios/Runner/Assets.xcassets/AppIcon.appiconset/128.png"
)

# Function to resize image using sips
resize_image() {
    local size=$1
    local output_path=$2
    local dir=$(dirname "$output_path")
    
    # Create directory if it doesn't exist
    mkdir -p "$dir"
    
    # Resize using sips (macOS built-in tool)
    # sips resizes maintaining aspect ratio, so we use --resampleHeightWidthMax to fit within size
    sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$output_path" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Generated $output_path (${size}x${size})"
    else
        echo "  ✗ Failed to generate $output_path"
        return 1
    fi
}

# Generate Android Adaptive Icon Foregrounds
echo ""
echo "Generating Android Adaptive Icon Foregrounds..."
for entry in "${ANDROID_FOREGROUND_SIZES[@]}"; do
    size="${entry%%:*}"
    path="android/app/src/main/res/${entry#*:}"
    resize_image "$size" "$path"
done

# Generate Android Legacy Icons
echo ""
echo "Generating Android Legacy Icons..."
for entry in "${ANDROID_LEGACY_SIZES[@]}"; do
    size="${entry%%:*}"
    path="android/app/src/main/res/${entry#*:}"
    resize_image "$size" "$path"
done

# Generate iOS Icons
echo ""
echo "Generating iOS Icons..."
for entry in "${IOS_SIZES[@]}"; do
    size="${entry%%:*}"
    path="${entry#*:}"
    resize_image "$size" "$path"
done

# Note: iOS Contents.json uses numbered filenames (e.g., "180.png") which are
# already generated above. The named icons (e.g., "Icon-App-60x60@3x.png") are
# optional legacy formats and are not required by the current Contents.json.

echo ""
echo "✓ All icons generated successfully!"
echo ""
echo "Next steps:"
echo "1. Run 'flutter pub get' to ensure dependencies are updated"
echo "2. Run 'flutter pub run flutter_native_splash:create' to regenerate splash screens"
echo "3. Verify icons appear correctly in Android Studio and Xcode"

