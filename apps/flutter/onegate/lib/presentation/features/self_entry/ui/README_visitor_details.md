# Visitor Details Screen - Gatekeeper UI Implementation

## Overview

This implementation provides a visitor details screen that matches the Gatekeeper application UI design patterns. The screen displays visitor information in a clean, professional layout with proper styling and user experience elements.

## Features

### 🎨 **UI Design Elements**
- **OneGate Branding**: Consistent header with logo and "New Entry" button
- **Profile Picture**: Circular profile image with loading indicator ring
- **Pass ID Display**: Prominent pass ID with visual separator
- **Information Cards**: Clean card-based layout for visitor details
- **Pending Approval Message**: Conditional message card for approval status

### 📱 **Responsive Design**
- **Tablet Support**: Optimized layouts for larger screens
- **Adaptive Sizing**: Dynamic font sizes and spacing based on screen size
- **Touch-Friendly**: Proper touch targets and haptic feedback

### 🎯 **Key Components**

#### 1. Header Section
```dart
Widget _buildHeader(BuildContext context, bool isTablet)
```
- OneGate logo with gradient background
- App title with proper typography
- "New Entry" button with icon

#### 2. Visitor Profile Section
```dart
Widget _buildVisitorProfile(BuildContext context, bool isTablet)
```
- Circular profile image with loading indicator
- Pass ID display with visual separator
- Default profile image fallback

#### 3. Visitor Details Section
```dart
Widget _buildVisitorDetails(BuildContext context, bool isTablet)
```
- Visitor name with prominent typography
- Information rows with icons and labels
- Mobile, Coming From, and Unit details

#### 4. Pending Approval Message
```dart
Widget _buildPendingApprovalMessage(BuildContext context, bool isTablet)
```
- Conditional display based on approval status
- Information icon with message text
- Clean card design with shadows

## Usage

### Basic Implementation

```dart
import 'package:flutter_onegate/presentation/features/self_entry/ui/visitor_details_screen.dart';

// Navigate to visitor details screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const VisitorDetailsScreen(
      visitorName: 'Akshay',
      passId: '45605890',
      mobileNumber: '7738039366',
      comingFrom: 'Vashi',
      unit: 'Cyber One-1905',
      profileImageUrl: null, // Optional profile image URL
      isPendingApproval: true, // Show/hide approval message
    ),
  ),
);
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `visitorName` | `String` | ✅ | Visitor's full name |
| `passId` | `String` | ✅ | Visitor's pass ID number |
| `mobileNumber` | `String` | ✅ | Visitor's mobile number |
| `comingFrom` | `String` | ✅ | Visitor's origin location |
| `unit` | `String` | ✅ | Unit being visited |
| `profileImageUrl` | `String?` | ❌ | Optional profile image URL |
| `isPendingApproval` | `bool` | ❌ | Show pending approval message (default: true) |

### Demo Implementation

Use the `VisitorDetailsDemo` screen to test different configurations:

```dart
import 'package:flutter_onegate/presentation/features/self_entry/ui/visitor_details_demo.dart';

// Navigate to demo screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const VisitorDetailsDemo(),
  ),
);
```

## Design Patterns

### 🎨 **Color Scheme**
- **Primary Red**: `#F44336` - OneGate brand color
- **Text Dark**: `#212427` - Primary text color
- **Text Light**: `#57636C` - Secondary text color
- **Background**: `#FFFFFF` - Clean white background
- **Shadows**: Subtle black shadows with opacity

### 📐 **Spacing & Typography**
- **Responsive Sizing**: Dynamic sizing based on screen width
- **Consistent Spacing**: 8px base unit with multipliers
- **Typography Scale**: Proper font weights and sizes
- **Letter Spacing**: Enhanced readability with letter spacing

### 🎯 **Interactive Elements**
- **Haptic Feedback**: Light impact on interactions
- **Smooth Animations**: 200ms duration for state changes
- **Touch Targets**: Minimum 44px touch targets
- **Visual Feedback**: Proper hover and press states

## Integration Examples

### 1. Self Entry Flow Integration

```dart
// After successful visitor check-in
void _onVisitorCheckInSuccess(Visitor visitor) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => VisitorDetailsScreen(
        visitorName: visitor.name ?? 'Guest',
        passId: visitor.passId ?? '00000000',
        mobileNumber: visitor.mobile ?? '0000000000',
        comingFrom: visitor.comingFrom ?? 'Unknown',
        unit: visitor.unit ?? 'N/A',
        profileImageUrl: visitor.profileImageUrl,
        isPendingApproval: true,
      ),
    ),
  );
}
```

### 2. Gatekeeper Dashboard Integration

```dart
// From visitor log item tap
void _onVisitorLogTap(VisitorLog visitorLog) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VisitorDetailsScreen(
        visitorName: visitorLog.visitor?.name ?? 'Guest',
        passId: visitorLog.visitor?.passId ?? '00000000',
        mobileNumber: visitorLog.visitor?.mobile ?? '0000000000',
        comingFrom: visitorLog.visitor_coming_from ?? 'Unknown',
        unit: visitorLog.visitor_building_assignment ?? 'N/A',
        profileImageUrl: visitorLog.visitor?.profileImageUrl,
        isPendingApproval: visitorLog.allow_status != 'allowed_by_gatekeeper',
      ),
    ),
  );
}
```

## Customization

### Theme Customization

The screen uses consistent color constants that can be easily customized:

```dart
// Primary brand color
const Color(0xffF44336)

// Text colors
const Color(0xff212427) // Primary text
const Color(0xff57636C) // Secondary text

// Background colors
const Color(0xffFFEBEE) // Light red background for icons
```

### Layout Customization

Modify the responsive breakpoints by changing the tablet detection:

```dart
final isTablet = MediaQuery.of(context).size.width > 600;
```

## Best Practices

### ✅ **Do's**
- Use proper error handling for network images
- Implement proper loading states
- Follow the established color scheme
- Use consistent spacing and typography
- Test on both mobile and tablet devices

### ❌ **Don'ts**
- Don't hardcode colors outside the established palette
- Don't skip the responsive design considerations
- Don't forget to handle null/empty values gracefully
- Don't use inconsistent spacing or typography

## Testing

### Manual Testing Checklist
- [ ] Profile image loads correctly
- [ ] Default profile image shows when URL is null
- [ ] Pending approval message shows/hides correctly
- [ ] Responsive design works on different screen sizes
- [ ] All text is readable and properly formatted
- [ ] Touch interactions work smoothly
- [ ] Navigation works correctly

### Demo Testing
Use the `VisitorDetailsDemo` screen to test:
- Different visitor data configurations
- Pending vs approved visitor states
- Profile image loading and fallbacks
- Responsive design on different devices

## Future Enhancements

### Potential Improvements
- [ ] Add animation for profile image loading
- [ ] Implement pull-to-refresh functionality
- [ ] Add visitor status indicators
- [ ] Include visitor timeline/history
- [ ] Add contact actions (call, message)
- [ ] Implement visitor photo capture
- [ ] Add visitor notes/comments section

### API Integration
- [ ] Real-time visitor status updates
- [ ] Profile image upload functionality
- [ ] Visitor approval/rejection actions
- [ ] Push notifications for status changes

---

## Support

For questions or issues with this implementation, please refer to:
- OneGate UI Design System documentation
- Flutter Material Design guidelines
- OneGate development team

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Compatibility**: Flutter 3.0+
