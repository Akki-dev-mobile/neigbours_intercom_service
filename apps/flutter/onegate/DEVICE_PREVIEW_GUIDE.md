# Device Preview Guide

## What is Device Preview?

Device Preview is a powerful Flutter package that allows you to preview your app on different device sizes, orientations, and configurations during development. This helps ensure your app looks great across various devices.

## Features Added

- **Multiple Device Previews**: Test your app on iPhone, Android, tablets, and more
- **Orientation Testing**: Switch between portrait and landscape modes
- **Text Scale Testing**: Test accessibility with different text sizes
- **Dark/Light Mode Testing**: Preview both theme modes
- **Responsive Design Testing**: See how your UI adapts to different screen sizes
- **Debug Mode Only**: Device Preview is only enabled in debug mode to avoid affecting production builds

## How to Use

### 1. Enable Device Preview

Device Preview is automatically enabled when running the app in debug mode:

```bash
flutter run --debug
```

### 2. Device Preview Controls

When the app launches in debug mode, you'll see:

- A device frame around your app
- Control panel on the right side with:
  - Device selector (iPhone 14, Pixel 7, iPad, etc.)
  - Orientation controls
  - Text scale factor slider
  - Theme mode toggle
  - Accessibility settings

### 3. Testing Different Devices

1. Click on the device selector
2. Choose from available devices:
   - **Phones**: iPhone 14/15, Samsung Galaxy, Pixel series
   - **Tablets**: iPad Pro, Samsung Tab
   - **Desktop**: macOS, Windows
   - **Custom**: Create your own device specs

### 4. Testing Orientations

- Toggle between portrait and landscape
- See how your responsive design adapts
- Check for layout issues in different orientations

### 5. Accessibility Testing

- Adjust text scale factor (0.5x to 3.0x)
- Test with different text sizes
- Ensure UI remains usable at extreme scales

## OneGate App Integration

The Device Preview has been integrated with:

- **ScreenUtil**: Maintains responsive design scaling
- **Network Log Overlay**: Works alongside device preview in debug mode
- **Theme Manager**: Previews both light and dark themes
- **All Providers**: Full app functionality preserved

## Technical Implementation

```dart
runApp(
  DevicePreview(
    enabled: kDebugMode, // Only in debug mode
    builder: (context) => ScreenUtilInit(
      // ... your app configuration
      child: MultiProvider(
        providers: [...],
        child: const MyApp(),
      ),
    ),
  ),
);
```

## MaterialApp Configuration

```dart
MaterialApp(
  useInheritedMediaQuery: true,
  locale: DevicePreview.locale(context),
  builder: DevicePreview.appBuilder,
  // ... rest of your app config
)
```

## Tips for Testing

1. **Test Key Screens**: Focus on login, dashboard, and main user flows
2. **Check Responsive Breakpoints**: Ensure proper layout on tablets vs phones
3. **Verify Touch Targets**: Ensure buttons are appropriately sized
4. **Test Text Overflow**: Check long text doesn't break layouts
5. **Validate Form Layouts**: Ensure forms work well on different screen sizes

## Performance Notes

- Device Preview only runs in debug mode
- No impact on release builds
- Can be disabled by setting `enabled: false` in the DevicePreview widget

## Troubleshooting

If Device Preview doesn't appear:

1. Ensure you're running in debug mode (`flutter run --debug`)
2. Check that `kDebugMode` is true
3. Verify the device_preview package is installed (`flutter pub get`)

## Production Builds

Device Preview is automatically disabled in production builds, so you don't need to worry about it affecting your released app.
