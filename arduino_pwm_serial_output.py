#!/usr/bin/env python3
# arduino_pwm_serial_output.py
#
# Arduino PWM serial output controller for eye tracking
#
# Packet format (8 ASCII bytes, no separators):
#     UyyyLxxx, D050R000, …    (always exactly 8 chars)
#
#   dirV = 'U' or 'D'                    (up / down)
#   yyy  = |dy|, as 3-digit number        (vertical  magnitude)
#   dirH = 'R' or 'L'                    (right / left)
#   xxx  = |dx|, as 3-digit number       (horizontal magnitude)
#
# If no face detected → "N000N000"

import serial
import serial.tools.list_ports
import time
import sys
import threading
import atexit
import signal
import requests
import socket
from eye_detection_model import EyeDetectionModel

# Global configuration
REFERENCE_OFFSET_PIXELS = 210  # Pixels above center for target reference point


def find_arduino_port():
    """
    Automatically detect Arduino serial port.

    Returns:
        str: Arduino port path, or None if not found
    """
    ports = serial.tools.list_ports.comports()

    # Look for common Arduino identifiers
    for port in ports:
        port_name = port.device.lower()
        description = (port.description or "").lower()

        # Check for Arduino-like ports
        if (
            "usbmodem" in port_name
            or "arduino" in description
            or "ch340" in description
            or "ch341" in description
            or "ftdi" in description
        ):
            print(
                f"🔍 Found potential Arduino port: {port.device} ({port.description})"
            )
            return port.device

    print("⚠️ No Arduino port detected automatically")
    return None


def check_arduino_wifi_status(arduino_ip="192.168.1.60", port=8080, timeout=2):
    """
    Check if Arduino WiFi server is accessible and get plotter status.
    
    Args:
        arduino_ip (str): Arduino IP address
        port (int): Arduino server port
        timeout (int): Connection timeout in seconds
        
    Returns:
        dict: Status response or None if not accessible
    """
    try:
        response = requests.get(f"http://{arduino_ip}:{port}/status", timeout=timeout)
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        print(f"⚠️ Arduino WiFi not accessible: {e}")
    return None

class ArduinoPWMSerialOutput:
    """
    Arduino PWM serial output controller for eye tracking feedback.
    Sends directional LED control packets based on eye position.
    Supports both serial and WiFi communication modes.
    """

    def __init__(self, serial_port=None, baud_rate=115200, deadzone_pixels=10, 
                 arduino_ip="192.168.1.60", arduino_port=8080):
        """
        Initialize Arduino communication (serial and/or WiFi).

        Args:
            serial_port (str): Arduino serial port path (None if no Arduino)
            baud_rate (int): Serial communication baud rate
            deadzone_pixels (int): Deadzone radius in pixels around frame center
            arduino_ip (str): Arduino WiFi IP address
            arduino_port (int): Arduino WiFi server port
        """
        print(f"Initializing eye tracking system...")
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.deadzone_pixels = deadzone_pixels
        self.arduino = None
        
        # WiFi communication setup
        self.arduino_ip = arduino_ip
        self.arduino_port = arduino_port
        self.wifi_enabled = False
        self.plotter_enabled = False

        if serial_port:
            print(f"Serial port: {serial_port}, baud rate: {baud_rate}")
            try:
                self.arduino = serial.Serial(serial_port, baud_rate, timeout=1)
                print("✓ Arduino connection established")
                time.sleep(2)  # Allow board reset
            except Exception as e:
                print(f"✗ Failed to connect to Arduino: {e}")
                print("📺 Continuing with camera display only")
                self.arduino = None
        else:
            print("📺 No Arduino port specified - checking WiFi connection")
            
        # Check WiFi connection to Arduino
        print(f"🌐 Checking Arduino WiFi connection at {arduino_ip}:{arduino_port}")
        wifi_status = check_arduino_wifi_status(arduino_ip, arduino_port)
        if wifi_status:
            self.wifi_enabled = True
            self.plotter_enabled = wifi_status.get('enabled', False)
            print(f"✓ Arduino WiFi connected - Plotter {'enabled' if self.plotter_enabled else 'disabled'}")
        else:
            print("⚠️ Arduino WiFi not accessible - serial communication only")

        # Initialize eye detection model
        try:
            self.eye_model = EyeDetectionModel(
                deadzone_pixels=self.deadzone_pixels,
                reference_offset_pixels=REFERENCE_OFFSET_PIXELS,
            )
            print("✓ Eye detection model initialized")
        except Exception as e:
            print(f"✗ Failed to initialize eye detection model: {e}")
            raise

        # Frame dimensions (should match eye detection model)
        self.frame_w = self.eye_model.frame_w
        self.frame_h = self.eye_model.frame_h
        print(f"✓ Camera resolution: {self.frame_w}x{self.frame_h}")

        # Cleanup tracking
        self._cleanup_called = False
        self._cleanup_lock = threading.Lock()

        # Register cleanup handlers
        atexit.register(self.cleanup)
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

        print("Eye tracking system ready!")

    def _calculate_directional_packet(self, eye_x, eye_y):
        """
        Calculate directional packet from eye coordinates.

        Args:
            eye_x (int): Eye x coordinate
            eye_y (int): Eye y coordinate

        Returns:
            str: 8-character directional packet
        """
        # Reference point is REFERENCE_OFFSET_PIXELS above center (after 180-degree rotation)
        reference_x = self.frame_w // 2
        reference_y = self.frame_h // 2 - REFERENCE_OFFSET_PIXELS

        # Compute deltas relative to reference point
        dx = eye_x - reference_x  # + = right,  - = left
        dy = eye_y - reference_y  # + = down,   - = up

        # Check if within deadzone
        distance = (dx**2 + dy**2) ** 0.5
        if distance <= self.deadzone_pixels:
            return "U000L000"  # Eye detected and in target zone

        dir_v = "U" if dy <= 0 else "D"
        dir_h = "L" if dx <= 0 else "R"

        dist_v = abs(dy)  # vertical magnitude
        dist_h = abs(dx)  # horizontal magnitude

        return f"{dir_v}{dist_v:03d}{dir_h}{dist_h:03d}"

    def send_packet(self, packet):
        """
        Send packet to Arduino via serial and/or WiFi.

        Args:
            packet (str): 8-character packet to send
        """
        # Send via serial if available
        if self.arduino is not None:
            try:
                if not self.arduino.is_open:
                    print("⚠️  Arduino connection closed - attempting to reconnect...")
                    self.arduino.open()
                self.arduino.write(packet.encode())
                self.arduino.flush()  # Ensure packet is sent immediately
            except Exception as e:
                print(f"⚠️  Failed to send packet '{packet}' via serial: {e}")
                # Try to reconnect
                try:
                    print("🔄 Attempting to reconnect to Arduino...")
                    if self.arduino:
                        self.arduino.close()
                    import serial

                    self.arduino = serial.Serial(
                        self.serial_port, self.baud_rate, timeout=1
                    )
                    print("✓ Serial reconnection successful")
                except Exception as reconnect_error:
                    print(f"❌ Serial reconnection failed: {reconnect_error}")
                    print("📺 Continuing without serial communication")
                    self.arduino = None
        
        # Note: WiFi communication is handled by plotter state management
        # The Arduino only processes serial packets when plotter is enabled via WiFi

    def check_plotter_status(self):
        """Check and update plotter status via WiFi."""
        if self.wifi_enabled:
            try:
                status = check_arduino_wifi_status(self.arduino_ip, self.arduino_port, timeout=1)
                if status:
                    old_status = self.plotter_enabled
                    self.plotter_enabled = status.get('enabled', False)
                    if old_status != self.plotter_enabled:
                        print(f"📊 Plotter status changed: {'enabled' if self.plotter_enabled else 'disabled'}")
                    return True
            except Exception as e:
                print(f"⚠️ Failed to check plotter status: {e}")
        return False
    
    def run(self, debug_display=True):
        """
        Main loop for eye tracking and Arduino communication.

        Args:
            debug_display (bool): Whether to show debug visualization
        """
        print("Starting eye tracking loop...")
        print("📱 Connect iOS app to Arduino WiFi (192.168.4.1) to control plotter")
        print("Press 'q' in the camera window or Ctrl+C to stop")
        loop_count = 0
        last_eye_status = None
        last_status_check = 0
        
        try:
            while True:
                loop_count += 1
                current_time = time.time()
                
                # Check plotter status periodically (every 5 seconds)
                if current_time - last_status_check > 5:
                    self.check_plotter_status()
                    last_status_check = current_time

                # Get eye location from model
                try:
                    eye_x, eye_y = self.eye_model.get_eye_location(debug_display=False)
                except Exception as e:
                    print(f"Error getting eye location: {e}")
                    eye_x, eye_y = None, None

                if eye_x is not None and eye_y is not None:
                    # Calculate and send directional packet
                    packet = self._calculate_directional_packet(eye_x, eye_y)
                    if last_eye_status != "detected":
                        last_eye_status = "detected"
                else:
                    # No eye detected
                    packet = "N000N000"
                    if last_eye_status != "not_detected":
                        last_eye_status = "not_detected"

                # Send packet to Arduino
                self.send_packet(packet)

                # Display frame with packet info if debug is enabled
                if debug_display:
                    try:
                        # Create packet info with plotter status
                        status_text = f"Plotter: {'ON' if self.plotter_enabled else 'OFF'}"
                        if self.wifi_enabled:
                            status_text += " (WiFi)"
                        elif self.arduino:
                            status_text += " (Serial)"
                        else:
                            status_text += " (No Connection)"
                        
                        packet_with_status = f"{packet} | {status_text}"
                        self.eye_model.display_frame_with_packet(packet_with_status, eye_x, eye_y)
                    except Exception as e:
                        print(f"Error displaying camera frame: {e}")

                # Check for quit command (only if debug display is enabled)
                if debug_display:
                    import cv2

                    key = cv2.waitKey(1) & 0xFF
                    if key == ord("q"):
                        print("Quit key pressed")
                        break

        except KeyboardInterrupt:
            print("\n🛑 Interrupted by user")
        except Exception as e:
            print(f"\n❌ Unexpected error in main loop: {e}")
        finally:
            print("\n📴 Shutting down...")
            self.cleanup()

    def _signal_handler(self, signum, frame):
        """Handle termination signals gracefully."""
        print(f"\n🛑 Received signal {signum}, initiating cleanup...")
        self.cleanup()
        sys.exit(0)

    def cleanup(self):
        """Clean up all resources with comprehensive error handling."""
        with self._cleanup_lock:
            if self._cleanup_called:
                return
            self._cleanup_called = True

        print("\n🧹 Starting comprehensive cleanup...")

        # Step 1: Send neutral signal to Arduino before shutdown
        try:
            if hasattr(self, "arduino") and self.arduino and self.arduino.is_open:
                self.arduino.write(b"N000N000")  # Send neutral signal
                self.arduino.flush()  # Ensure data is sent
                time.sleep(0.1)  # Give Arduino time to process
                print("✓ Sent neutral signal to Arduino")
        except Exception as e:
            print(f"⚠️  Error sending neutral signal: {e}")

        # Step 2: Clean up eye model (includes camera and MediaPipe)
        try:
            if hasattr(self, "eye_model") and self.eye_model:
                self.eye_model.cleanup()
                self.eye_model = None
                print("✓ Eye detection model cleaned up")
        except Exception as e:
            print(f"⚠️  Error cleaning up eye model: {e}")

        # Step 3: Close Arduino connection with multiple attempts
        arduino_closed = False
        for attempt in range(3):
            try:
                if hasattr(self, "arduino") and self.arduino:
                    if self.arduino.is_open:
                        self.arduino.close()
                    self.arduino = None
                    arduino_closed = True
                    print("✓ Arduino connection closed")
                    break
            except Exception as e:
                print(f"⚠️  Arduino close attempt {attempt + 1} failed: {e}")
                time.sleep(0.1)

        if not arduino_closed:
            print("⚠️  Warning: Arduino connection may not have been fully closed")

        # Step 4: Final OpenCV cleanup
        try:
            import cv2

            cv2.destroyAllWindows()
            # Multiple waitKey calls to ensure cleanup
            for _ in range(10):
                cv2.waitKey(1)
            print("✓ Final OpenCV cleanup completed")
        except Exception as e:
            print(f"⚠️  Error in final OpenCV cleanup: {e}")

        # Step 5: Force garbage collection
        try:
            import gc

            gc.collect()
            print("✓ Garbage collection completed")
        except Exception as e:
            print(f"⚠️  Error during garbage collection: {e}")

        print("✅ Comprehensive cleanup complete")

    def __del__(self):
        """Destructor to ensure cleanup on object deletion."""
        try:
            self.cleanup()
        except Exception:
            pass  # Ignore errors during destruction


def main():
    """Main function to run the eye tracking system with comprehensive error handling."""
    print("🚀 Arduino Eye Tracking System")
    print("=" * 40)

    controller = None
    try:
        # Setup signal handlers for graceful shutdown
        def signal_handler_main(signum, frame):
            print(f"\n🛑 Received signal {signum} in main, cleaning up...")
            if controller:
                controller.cleanup()
            sys.exit(0)

        signal.signal(signal.SIGINT, signal_handler_main)
        signal.signal(signal.SIGTERM, signal_handler_main)

        # Automatically detect Arduino port
        arduino_port = find_arduino_port()
        if not arduino_port:
            print(
                f"💡 Available ports: {[port.device for port in serial.tools.list_ports.comports()]}"
            )
            print("📺 No Arduino detected - continuing with camera display only")

        # Create and run the Arduino PWM serial output controller
        controller = ArduinoPWMSerialOutput(arduino_port)
        controller.run(debug_display=True)

    except KeyboardInterrupt:
        print("\n🛑 Program stopped by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback

        traceback.print_exc()
    finally:
        # Ensure cleanup happens even if controller creation failed
        if controller:
            try:
                controller.cleanup()
            except Exception as cleanup_error:
                print(f"⚠️  Error during final cleanup: {cleanup_error}")

        # Final system cleanup
        try:
            import cv2

            cv2.destroyAllWindows()
            for _ in range(5):
                cv2.waitKey(1)
        except Exception:
            pass

        print("👋 Eye tracking system shutdown complete")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"💥 Fatal error in main: {e}")
        sys.exit(1)
