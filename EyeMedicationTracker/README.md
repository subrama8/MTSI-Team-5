# Eye Medication Tracker - iOS App

A native iOS app for tracking eye medication schedules with Arduino R4 WiFi integration for automated eye-tracking assistance.

## 🎯 Features

### 📱 Native iOS Experience
- **SwiftUI Interface**: Modern, native iOS design with light blue and white theme
- **Large Touch Targets**: Optimized for older users with accessibility in mind
- **VoiceOver Support**: Full screen reader compatibility
- **Dynamic Type**: Supports iOS text size preferences
- **Haptic Feedback**: Tactile responses for better usability

### 🔗 Arduino Integration
- **WiFi Communication**: Connect to Arduino R4 WiFi over local network
- **Device Discovery**: Automatic scanning and manual IP entry
- **Real-time Control**: Start/stop plotter with large toggle button
- **Eye Tracking Interface**: Camera integration with AVFoundation
- **Status Monitoring**: Live device status and connection management

### 💊 Medication Management
- **Core Data Storage**: Reliable local data persistence
- **Visual Calendar**: Month view with dose indicators and completion status
- **Smart Scheduling**: Multiple doses per day with custom timing
- **Compliance Tracking**: Statistics and progress monitoring

### 🔔 Native Notifications
- **UNUserNotificationCenter**: iOS native notification system
- **Interactive Notifications**: Mark complete or snooze from notifications
- **Background Scheduling**: Notifications work even when app is closed
- **Custom Sounds**: Configurable notification sounds

### 📊 Usage Tracking
- **Automatic Logging**: Device usage automatically recorded
- **Manual Entry**: Backlog medication when away from device
- **Filtering Options**: View by type (automatic, scheduled, manual)
- **Data Export**: Share data with healthcare providers

## 📋 Requirements

### iOS Development
- **Xcode 15.0+**
- **iOS 16.0+ deployment target**
- **iPhone and iPad support**
- **Apple Developer Account** (for device testing and App Store)

### Hardware Integration
- **Arduino R4 WiFi** with WiFi-enabled firmware
- **Camera Access** for eye tracking
- **Local Network Access** for Arduino communication

## 🚀 Installation & Setup

### 1. Open in Xcode
```bash
# Clone or download the project
cd EyeMedicationTracker
open EyeMedicationTracker.xcodeproj
```

### 2. Configure Project
1. **Bundle Identifier**: Change to your unique identifier in project settings
2. **Team/Signing**: Select your Apple Developer team for code signing
3. **Deployment Target**: Ensure iOS 16.0+ is set

### 3. Required Permissions
The app requests these iOS permissions:
- **Camera**: For eye tracking interface
- **Local Network**: To discover and connect to Arduino devices
- **Notifications**: For medication reminders

### 4. Arduino Setup
1. **Upload WiFi Firmware**: Use `PlotterMovementPID_WiFi.ino` from the web app project
2. **Configure Network**: Connect Arduino to same WiFi as iPhone
3. **Note IP Address**: Arduino will display IP in serial monitor

### 5. Build & Run
1. **Simulator**: Test basic UI and data features
2. **Physical Device**: Required for camera access and Arduino communication
3. **Arduino Connection**: Use "Find Device" in app to connect

## 🏗️ Architecture

### SwiftUI + Core Data
```
EyeMedicationTracker/
├── Models/                    # Core Data model classes
├── Views/                     # SwiftUI views and components  
│   ├── DeviceControlView.swift        # Arduino connection & control
│   ├── MedicationCalendarView.swift   # Scheduling & calendar
│   ├── MedicationLogView.swift        # Usage history
│   ├── SettingsView.swift             # App preferences
│   └── Components/                    # Reusable UI components
├── ViewModels/                # View state management
├── Services/                  # Business logic & API
│   ├── ArduinoService.swift           # Arduino WiFi communication
│   ├── NotificationManager.swift     # iOS notifications
│   └── DataManager.swift             # Core Data operations
└── Resources/                 # Assets, colors, localization
```

### Key Services

#### ArduinoService
- **Device Discovery**: Network scanning for Arduino devices
- **HTTP Communication**: REST API calls to Arduino endpoints
- **Real-time Status**: Connection monitoring and error handling
- **Command Execution**: Start/stop plotter, send eye data

#### NotificationManager
- **Permission Handling**: Request and manage notification permissions
- **Scheduling**: Create recurring medication reminders
- **Interactive Actions**: Handle notification responses (complete/snooze)
- **Background Sync**: Update scheduled notifications

#### Core Data Stack
- **MedicationSchedule**: Medication timing and dosage information
- **ScheduledDose**: Individual dose instances with completion status
- **MedicationLog**: Usage history with automatic and manual entries

## 📱 Usage Guide

### First Launch
1. **Grant Permissions**: Allow camera, network, and notification access
2. **Create Schedule**: Add your first medication in the Schedule tab
3. **Connect Device**: Find and connect to Arduino in Device tab
4. **Test Notifications**: Verify reminders are working in Settings

### Daily Use
1. **Receive Reminders**: Get notifications 10 minutes before medication time
2. **Use Device**: Tap large ON/OFF toggle to activate eye tracker
3. **Automatic Logging**: Usage is logged automatically when device is used
4. **Manual Entries**: Add doses taken when away from home

### Arduino Integration
- **Same Network**: Ensure iPhone and Arduino are on same WiFi
- **Auto Discovery**: App scans network for compatible devices
- **Manual Connection**: Enter Arduino IP if auto-discovery fails
- **Status Monitoring**: Connection status shown in real-time

## 🎨 Design System

### Colors
- **Primary**: Light Blue (#0ea5e9) - Main accent color
- **Background**: Dynamic system backgrounds (light/dark mode ready)
- **Text**: High contrast for accessibility
- **Status**: Green (connected), Red (error), Yellow (warning)

### Typography
- **Dynamic Type**: Supports iOS text size preferences
- **Accessibility**: Bold text support for better readability
- **Hierarchical**: Clear information architecture

### Accessibility
- **VoiceOver**: Full screen reader support with proper labels
- **Large Touch Targets**: Minimum 44pt touch targets
- **High Contrast**: Color choices work with accessibility settings
- **Reduced Motion**: Respects user motion preferences

## 🔧 Customization

### Notification Timing
```swift
// In NotificationManager.swift
private func scheduleNotification(reminderMinutes: Int) {
    // Default is 10 minutes, can be customized per schedule
}
```

### Arduino Endpoints
```swift
// In ArduinoService.swift
private let endpoints = [
    "status": "/api/status",
    "start": "/api/plotter/start", 
    "stop": "/api/plotter/stop",
    "eyeData": "/api/eye-data"
]
```

### UI Theme
```swift
// In UIComponents.swift
extension Color {
    static let lightBlue = Color("LightBlue")  // Customize in Assets.xcassets
}
```

## 📊 Data Management

### Local Storage
- **Core Data**: All medication data stored locally
- **UserDefaults**: App preferences and settings
- **No Cloud**: Data stays on device for privacy

### Data Export
- **JSON Format**: Structured export for healthcare providers
- **Privacy First**: User controls all data sharing

### Backup Strategy
- **iCloud Backup**: Automatic with iOS device backup
- **Manual Export**: JSON export feature in Settings

## 🚀 App Store Preparation

### Required Assets
1. **App Icons**: Various sizes for different devices
2. **Launch Screen**: SwiftUI-based launch screen
3. **Screenshots**: iPhone and iPad screenshots for App Store
4. **Privacy Labels**: Declare data usage in App Store Connect

### Submission Checklist
- [ ] Test on multiple devices (iPhone, iPad)
- [ ] Verify Arduino integration works
- [ ] Test notification permissions and functionality  
- [ ] Review accessibility with VoiceOver
- [ ] Generate screenshots for App Store
- [ ] Complete App Store metadata

## 🐛 Troubleshooting

### Arduino Connection Issues
- Ensure Arduino and iPhone are on same WiFi network
- Check Arduino IP address in serial monitor
- Try manual IP entry if auto-discovery fails
- Verify firewall settings don't block local connections

### Notification Problems
- Check notification permissions in iOS Settings
- Ensure app has background app refresh enabled
- Test with "Send Test Notification" in Settings
- Verify Do Not Disturb settings

### Camera Access
- Grant camera permission when prompted
- Check Privacy settings in iOS Settings > Privacy & Security > Camera
- Ensure good lighting for eye tracking
- Test camera access in eye tracking interface

## 🔒 Privacy & Security

### Data Privacy
- **Local Storage**: All data stored on device
- **No Tracking**: No analytics or user tracking
- **Camera Access**: Only used for eye tracking, not stored
- **Network**: Only communicates with user's Arduino device

### Security
- **Local Network Only**: Arduino communication stays on local network
- **No External APIs**: No data sent to external servers
- **Secure Storage**: Core Data encrypted at rest on device

## 📄 License

This project is designed for medical assistance and eye care management. Ensure compliance with medical device regulations in your jurisdiction before commercial use.

## 🆘 Support

For technical support:
1. Check Arduino serial monitor for connection debugging
2. Verify iOS permissions are granted correctly
3. Test on different network configurations  
4. Review Xcode console for error messages
5. Ensure compatible iOS version (16.0+)