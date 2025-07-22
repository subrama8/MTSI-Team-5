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
from eye_detection_model import EyeDetectionModel


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
        if ('usbmodem' in port_name or 
            'arduino' in description or 
            'ch340' in description or 
            'ch341' in description or
            'ftdi' in description):
            print(f"🔍 Found potential Arduino port: {port.device} ({port.description})")
            return port.device
    
    print("⚠️ No Arduino port detected automatically")
    return None


class ArduinoPWMSerialOutput:
    """
    Arduino PWM serial output controller for eye tracking feedback.
    Sends directional LED control packets based on eye position.
    """

    def __init__(self, serial_port, baud_rate=115200, deadzone_pixels=10):
        """
        Initialize Arduino serial connection.

        Args:
            serial_port (str): Arduino serial port path
            baud_rate (int): Serial communication baud rate
            deadzone_pixels (int): Deadzone radius in pixels around frame center
        """
        print(f"Initializing eye tracking system...")
        print(f"Serial port: {serial_port}, baud rate: {baud_rate}")
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.deadzone_pixels = deadzone_pixels
        
        try:
            self.arduino = serial.Serial(serial_port, baud_rate, timeout=1)
            print("✓ Arduino connection established")
        except Exception as e:
            print(f"✗ Failed to connect to Arduino: {e}")
            raise
        
        time.sleep(2)  # Allow board reset

        # Initialize eye detection model
        try:
            self.eye_model = EyeDetectionModel(deadzone_pixels=self.deadzone_pixels)
            print("✓ Eye detection model initialized")
        except Exception as e:
            print(f"✗ Failed to initialize eye detection model: {e}")
            raise

        # Frame dimensions (should match eye detection model)
        self.frame_w = self.eye_model.frame_w
        self.frame_h = self.eye_model.frame_h
        print(f"✓ Camera resolution: {self.frame_w}x{self.frame_h}")
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
        # Compute deltas with scaling
        dx = eye_x - self.frame_w // 2  # + = right,  - = left
        dy = eye_y - self.frame_h // 2  # + = down,   - = up

        # Check if within deadzone
        distance = (dx ** 2 + dy ** 2) ** 0.5
        if distance <= self.deadzone_pixels:
            return "N000N000"  # No movement within deadzone

        dir_v = "U" if dy <= 0 else "D"
        dir_h = "L" if dx <= 0 else "R"

        dist_v = abs(dy)  # vertical magnitude
        dist_h = abs(dx)  # horizontal magnitude

        return f"{dir_v}{dist_v:03d}{dir_h}{dist_h:03d}"

    def send_packet(self, packet):
        """
        Send packet to Arduino.

        Args:
            packet (str): 8-character packet to send
        """
        try:
            if self.arduino is None:
                print("⚠️  Arduino connection lost - cannot send packet")
                return
            if not self.arduino.is_open:
                print("⚠️  Arduino connection closed - attempting to reconnect...")
                self.arduino.open()
            self.arduino.write(packet.encode())
        except Exception as e:
            print(f"⚠️  Failed to send packet '{packet}': {e}")
            # Try to reconnect
            try:
                print("🔄 Attempting to reconnect to Arduino...")
                if self.arduino:
                    self.arduino.close()
                import serial
                self.arduino = serial.Serial(self.serial_port, self.baud_rate, timeout=1)
                print("✓ Reconnection successful")
            except Exception as reconnect_error:
                print(f"❌ Reconnection failed: {reconnect_error}")
                self.arduino = None

    def run(self, debug_display=True):
        """
        Main loop for eye tracking and Arduino communication.

        Args:
            debug_display (bool): Whether to show debug visualization
        """
        print("Starting eye tracking loop...")
        print("Press 'q' in the camera window or Ctrl+C to stop")
        loop_count = 0
        last_eye_status = None
        try:
            while True:
                loop_count += 1
                
                # Get eye location from model
                try:
                    eye_x, eye_y = self.eye_model.get_eye_location(
                        debug_display=False
                    )
                except Exception as e:
                    print(f"Error getting eye location: {e}")
                    eye_x, eye_y = None, None

                if eye_x is not None and eye_y is not None:
                    # Calculate and send directional packet
                    packet = self._calculate_directional_packet(eye_x, eye_y)
                    if last_eye_status != "detected":
                        print(f"👁️  Eye detected - tracking active")
                        last_eye_status = "detected"
                else:
                    # No eye detected
                    packet = "N000N000"
                    if last_eye_status != "not_detected":
                        print("👁️  No eye detected - sending neutral signal")
                        last_eye_status = "not_detected"

                # Send packet to Arduino
                self.send_packet(packet)

                # Display frame with packet info if debug is enabled
                if debug_display:
                    try:
                        self.eye_model.display_frame_with_packet(packet, eye_x, eye_y)
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
            print("\nInterrupted by user")
        finally:
            print("Shutting down...")
            self.cleanup()

    def cleanup(self):
        """Clean up resources."""
        print("\n🧹 Starting cleanup...")
        
        # Clean up eye model first (includes camera and OpenCV windows)
        try:
            if hasattr(self, 'eye_model'):
                self.eye_model.cleanup()
                print("✓ Camera and OpenCV windows cleaned up")
        except Exception as e:
            print(f"⚠️  Error cleaning up camera: {e}")
        
        # Clean up Arduino connection
        try:
            if hasattr(self, 'arduino') and self.arduino:
                if self.arduino.is_open:
                    self.arduino.close()
                print("✓ Arduino connection closed")
        except Exception as e:
            print(f"⚠️  Error closing Arduino connection: {e}")
        
        # Force cleanup of any remaining OpenCV resources
        try:
            import cv2
            cv2.destroyAllWindows()
            # Give OpenCV time to properly close windows
            cv2.waitKey(1)
        except Exception as e:
            print(f"⚠️  Error in final OpenCV cleanup: {e}")
        
        print("✅ Cleanup complete")


def main():
    """Main function to run the eye tracking system."""
    print("🚀 Arduino Eye Tracking System")
    print("=" * 40)
    
    try:
        # Automatically detect Arduino port
        arduino_port = find_arduino_port()
        if not arduino_port:
            # Fallback to known ports if auto-detection fails
            fallback_ports = ["/dev/cu.usbmodemF412FA6399F42", "/dev/cu.usbmodem*", "COM3", "COM4", "COM5"]
            print(f"💡 Available ports: {[port.device for port in serial.tools.list_ports.comports()]}")
            print("❌ Please connect Arduino or check the port manually")
            sys.exit(1)
        
        # Create and run the Arduino PWM serial output controller
        controller = ArduinoPWMSerialOutput(arduino_port)
        controller.run(debug_display=True)
    except KeyboardInterrupt:
        print("\n🛑 Program stopped by user")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
