# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an eye-tracking system project with four main components:
1. **Web-based Face Detection UI** - React/TypeScript application for eye center detection using MediaPipe
2. **Python Eye Tracker** - Real-time eye tracking with computer vision
3. **Arduino LED Controller** - Hardware feedback system using PWM for directional LED indicators
4. **Arduino Plotter Controller** - PID-controlled motor system for precise eye-tracking movement

## Development Commands

### Web Application (React/TypeScript)
```bash
cd project-bolt-sb1-rbczq2ye/project
npm install          # Install dependencies
npm run dev          # Start development server
npm run build        # Build for production
npm run lint         # Run ESLint
npm run preview      # Preview production build
```

### Python Components
```bash
python3 eye_detection_model.py     # Run eye tracking with camera
python3 arduino_pwm_serial_output.py  # Run eye tracking with LED feedback
python3 plotter_movement.py        # PID controller utilities
```

### Arduino
- **LED Feedback**: Upload `arduino_pwm_directional_feedback.ino` for LED indicators
- **Plotter Control**: Upload `PlotterMovementPID/PlotterMovementPID.ino` for motor control

## Architecture

### Web Application Structure
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS
- **Face Detection**: MediaPipe Face Mesh integration with both CDN and npm package support
- **Key Components**:
  - `FaceMeshProcessor`: Handles MediaPipe initialization and image processing
  - `FaceAnalysisResult`: Displays detection results with eye center coordinates
  - `ImageUpload`: File upload interface

### Python Eye Tracking System
- **Real-time Processing**: Uses OpenCV + MediaPipe for live camera feed
- **Serial Communication**: Sends eye position data to Arduino via serial port
- **Protocol**: 8-byte ASCII packets (e.g., "U050R100", "D200L075", "N000N000")
- **Data Format**: Direct eye position distance values (no scaling applied)

### Arduino LED Feedback
- **Hardware**: Controls 4 PWM LEDs (top, bottom, left, right)
- **Communication**: Receives 8-byte packets via serial (115200 baud)
- **Behavior**: 
  - Directional LEDs modulate based on eye position
  - All LEDs set to max brightness when no eye detected
- **Pin Map**: Top(11), Bottom(5), Right(10), Left(6)

### Arduino Plotter Controller
- **Hardware**: Controls 2 stepper motors (X and Y axis) with PID feedback
- **Communication**: Receives 8-byte packets via serial (115200 baud)
- **Behavior**:
  - Motors adjust position based on eye tracking error
  - PID controllers provide smooth, precise movement
  - Stops movement when no eye detected ("N000N000")
  - Automatic PID reset prevents integral windup
- **Pin Map**: Motor1(EN1=9, IN1A=12, IN1B=13), Motor2(EN2=3, IN2A=5, IN2B=7)

## Key Integration Points

### Data Flow
1. Python script captures camera feed → MediaPipe face detection
2. Eye center coordinates calculated → Scaled directional values
3. Serial packet sent to Arduino → LED intensity control OR motor positioning
4. Web app provides standalone image analysis interface

### Integration Options
- **LED Feedback**: Use `arduino_pwm_serial_output.py` with LED controller Arduino
- **Plotter Control**: Use `arduino_pwm_serial_output.py` with PlotterMovementPID Arduino
- Both systems use identical 8-byte packet protocol for seamless switching

### Serial Protocol
- Format: `[dirV][valV][dirH][valH]` (8 ASCII chars)
- Directions: U/D (vertical), R/L (horizontal), N (none)
- Values: 3-digit distance values (direct eye position offset)
- Example: "U050R100" = Up 50 pixels, Right 100 pixels

## Development Notes

### MediaPipe Integration
- Web app supports both CDN and npm package loading
- Production uses CDN for reliability
- Development uses local npm packages
- Handle initialization timeouts and errors gracefully

### Hardware Configuration
- Arduino serial port: `/dev/cu.usbmodemF412FA6399F42` (update as needed)
- Serial baud rate: 115200 (consistent across all Arduino components)
- Camera index: 1 (external camera, adjust if needed)
- Frame size: 640x480 for optimal performance

### Error Handling
- Web app includes retry mechanisms for MediaPipe failures
- Python script includes proper camera and serial cleanup
- Arduino handles malformed packets gracefully with validation and buffer clearing
- PlotterMovementPID includes packet validation and automatic error recovery

### PlotterMovementPID Features
- **Packet Validation**: Validates direction characters (U/D/N, L/R/N) and digit format
- **'N' Packet Handling**: Properly stops motors when no eye detected
- **Buffer Recovery**: Clears serial buffer on invalid packets to prevent sync issues
- **PID Reset**: Automatically resets PID controllers to prevent integral windup
- **Robust Communication**: 8-byte packet format matches Python sender exactly