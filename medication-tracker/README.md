# Eye Medication Tracker

A modern Progressive Web App (PWA) for tracking eye medication schedules with Arduino R4 WiFi integration for automated eye-tracking assistance.

## Features

### 🎯 Modern & Accessible UI
- Light blue and white color scheme
- Large, touch-friendly buttons optimized for older users
- High contrast design for better visibility
- Responsive layout for mobile and tablet devices

### 📱 Progressive Web App
- Works offline with full functionality
- Installable on mobile devices
- Push notifications for medication reminders
- Fast loading and responsive

### 🔗 Arduino Device Integration
- WiFi connection to Arduino R4 WiFi plotter
- Automatic device discovery on local network
- Manual IP configuration option
- Real-time eye tracking with camera integration
- On/Off toggle for plotter control

### 💊 Medication Management
- Interactive calendar for scheduling medications
- Multiple daily doses with custom timing
- Automatic usage logging when device is used
- Manual backlog entry for missed doses
- Compliance tracking and statistics

### 🔔 Smart Reminders
- Customizable reminder times (5-60 minutes before)
- Push notifications with sound
- Snooze functionality
- Mark complete directly from notifications

### 📊 Usage Tracking
- Automatic logging when eye tracker is used
- Manual entry for away-from-home usage
- Historical view with filtering options
- Export data functionality

## Installation

### Prerequisites
- Node.js 18+ and npm
- Arduino R4 WiFi board
- Compatible camera for eye tracking

### Setup Instructions

1. **Clone and install the web app:**
   ```bash
   cd medication-tracker
   npm install
   ```

2. **Upload Arduino firmware:**
   - Open `PlotterMovementPID/PlotterMovementPID_WiFi.ino` in Arduino IDE
   - Install required libraries: `WiFiS3`, `ArduinoJson`
   - Upload to your Arduino R4 WiFi board

3. **Configure Arduino WiFi:**
   - Connect to Arduino via serial monitor (115200 baud)
   - Send command: `WIFI_CONFIG:YourWiFiName,YourPassword`
   - Note the IP address displayed when connected

4. **Start the web app:**
   ```bash
   npm run dev
   ```

5. **Access the app:**
   - Open http://localhost:3000 in your browser
   - Allow notification permissions when prompted
   - Go to Device tab to connect to your Arduino

## Usage Guide

### First Time Setup
1. Create your first medication schedule in the Calendar tab
2. Connect to your Arduino device in the Device tab
3. Test the connection and eye tracking interface

### Daily Use
1. Use the large ON/OFF toggle to start/stop the eye tracker
2. Receive automatic reminders 10 minutes before medication time
3. The app automatically logs usage when the device is activated
4. Manually log doses when away from the device

### Arduino Configuration
The Arduino code provides REST API endpoints:
- `GET /api/status` - Get device status
- `POST /api/plotter/start` - Start the plotter
- `POST /api/plotter/stop` - Stop the plotter  
- `POST /api/eye-data` - Send eye tracking data
- `GET /api/discover` - Device discovery

### Eye Tracking Protocol
The system uses 8-byte ASCII packets:
- Format: `[dirV][valV][dirH][valH]`
- Example: `"U050R100"` = Up 50 pixels, Right 100 pixels
- No eye detected: `"N000N000"`

## File Structure

```
medication-tracker/
├── src/
│   ├── components/
│   │   ├── DeviceControl/     # Arduino connection & control
│   │   ├── Calendar/          # Medication scheduling
│   │   ├── Logging/           # Usage history & manual entry
│   │   └── Settings.tsx       # App configuration
│   ├── services/
│   │   ├── arduino-wifi.ts    # Arduino communication
│   │   ├── medication-service.ts # Data management
│   │   └── notification-service.ts # Push notifications
│   ├── types/
│   │   └── medication.ts      # TypeScript interfaces
│   └── styles/
│       └── index.css         # Tailwind CSS with custom styles
├── public/
│   ├── sw.js                 # Service worker for PWA
│   └── manifest.json         # PWA manifest
└── PlotterMovementPID/
    └── PlotterMovementPID_WiFi.ino # Arduino firmware
```

## Data Storage

All data is stored locally in the browser using localStorage:
- `medication_schedules` - Medication schedules
- `scheduled_doses` - Generated dose reminders
- `medication_logs` - Usage history
- `arduino_ip` - Saved device IP address
- `app_settings` - User preferences

## Development

### Available Scripts
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

### Technology Stack
- **Frontend:** React 18 + TypeScript + Vite
- **Styling:** Tailwind CSS with custom accessibility features
- **PWA:** Vite PWA plugin with Workbox
- **Icons:** Heroicons
- **Date handling:** date-fns
- **Arduino:** WiFiS3 + ArduinoJson libraries

### Adding New Features
1. Follow the existing component structure
2. Use the MedicationService for data operations
3. Maintain accessibility standards (WCAG 2.1 AA)
4. Test with the Arduino integration

## Troubleshooting

### Arduino Connection Issues
- Ensure Arduino and device are on the same WiFi network
- Check serial monitor for IP address
- Try manual IP entry in device discovery
- Verify WiFi credentials are correct

### Notification Issues
- Check browser notification permissions
- Ensure app is installed as PWA for better notification support
- Test with the "Test Notification" button in settings

### Camera Access
- Grant camera permissions in browser
- Check camera privacy settings on device
- Ensure good lighting for eye tracking

## Hardware Requirements

### Arduino R4 WiFi Setup
- Arduino R4 WiFi board
- 2x Stepper motors for X/Y axis control
- Motor driver board
- Power supply (12V recommended)
- WiFi network access

### Pin Configuration
- Motor 1: EN=9, IN1A=12, IN1B=13
- Motor 2: EN=3, IN2A=5, IN2B=7

## Contributing

This project is designed for eye medication management. When contributing:
1. Maintain accessibility standards
2. Test with real Arduino hardware
3. Follow the established UI patterns
4. Consider older user needs in design decisions

## License

This project is for educational and medical assistance purposes. Please ensure compliance with medical device regulations in your jurisdiction.

## Support

For technical support:
1. Check Arduino serial monitor for connection issues
2. Verify browser supports required web APIs
3. Test with different network configurations
4. Review browser console for JavaScript errors