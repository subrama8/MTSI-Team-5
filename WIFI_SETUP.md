# Arduino R4 WiFi Plotter Control Setup

This guide explains how to set up WiFi communication between the iOS Innovision app and the Arduino R4 WiFi for plotter control.

## Arduino Setup

### 1. Update WiFi Credentials
In `PlotterMovementPID/PlotterMovementPID.ino`, update these lines with your WiFi network:

```cpp
const char* ssid = "YOUR_WIFI_SSID";        // Replace with your WiFi network name
const char* password = "YOUR_WIFI_PASSWORD"; // Replace with your WiFi password
```

### 2. Upload Code to Arduino R4 WiFi
1. Open Arduino IDE
2. Select Board: "Arduino R4 WiFi"
3. Upload `PlotterMovementPID/PlotterMovementPID.ino`
4. Open Serial Monitor (115200 baud) to see WiFi connection status

### 3. Find Arduino IP Address
After successful WiFi connection, the Arduino will print its IP address in the Serial Monitor:
```
WiFi connected! IP address: 192.168.1.XXX
Server started on port 8080
```

## iOS App Configuration

### Update Arduino IP in DeviceService.swift
If your Arduino gets a different IP address, update this line in `DeviceService.swift`:

```swift
private let arduinoHost = "192.168.1.XXX"  // Replace with your Arduino's IP
```

## Python Script Configuration

### Update IP in arduino_pwm_serial_output.py
If needed, update the Arduino IP in the Python script:

```python
# In ArduinoPWMSerialOutput.__init__()
arduino_ip="192.168.1.XXX"  # Replace with your Arduino's IP
```

## Network Requirements

### Same WiFi Network
- Arduino R4 WiFi and iOS device must be on the same WiFi network
- Ensure your router allows device-to-device communication (some guest networks block this)

### Port Access
- Arduino serves on port 8080
- Ensure firewall/router doesn't block this port

## Testing Connection

### 1. Test Arduino WiFi Server
From any device on the same network, visit:
```
http://ARDUINO_IP:8080/status
```
Should return JSON like: `{"status":"disabled","enabled":false,"wifi":true}`

### 2. Test iOS App Connection
1. Launch Innovision app
2. Tap "Connect to Plotter" 
3. Should show "Connected to Plotter" with status

### 3. Test Plotter Control
1. Tap "Start Plotter" - Arduino should respond with motors ready
2. Run `python3 arduino_pwm_serial_output.py` - should show camera feed
3. Eye tracking data will control motors when plotter is enabled

## API Endpoints

The Arduino WiFi server provides these HTTP endpoints:

- `GET /start` - Enable plotter motor control
- `GET /stop` - Disable plotter motor control  
- `GET /status` - Get current plotter status

All endpoints return JSON responses with status information.

## Troubleshooting

### Arduino Not Connecting to WiFi
- Check SSID and password are correct
- Ensure 2.4GHz WiFi (Arduino R4 doesn't support 5GHz)
- Check router compatibility

### iOS App Can't Connect
- Verify Arduino IP address is correct
- Ensure both devices on same network
- Check router firewall settings
- Try connecting from browser first

### Python Script Shows "Arduino WiFi not accessible"
- Check Arduino is powered and WiFi connected
- Verify IP address and port
- Test with browser: `http://ARDUINO_IP:8080/status`

### Motors Not Moving
- Ensure plotter is enabled via iOS app or `/start` endpoint
- Check serial connection between Python script and Arduino
- Verify eye detection is working (camera window shows eye tracking)

## System Flow

1. **Arduino starts** → Connects to WiFi → Starts HTTP server → Plotter disabled by default
2. **iOS app connects** → Gets plotter status → Can enable/disable plotter
3. **Python script runs** → Connects to camera → Sends eye tracking data via serial
4. **Arduino receives** → Only moves motors if plotter enabled via WiFi command

This ensures the camera stream continues working regardless of plotter state, but motor movement only occurs when explicitly enabled through the iOS app.