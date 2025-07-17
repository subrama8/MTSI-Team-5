#!/usr/bin/env python3
# arduino_pwm_serial_output.py
#
# Arduino PWM serial output controller for eye tracking
#
# Packet format (8 ASCII bytes, no separators):
#     UyyyLxxx, D050R000, …    (always exactly 8 chars)
#
#   dirV = 'U' or 'D'                    (up / down)
#   yyy  = |dy| // 2, clamped 0‑255      (vertical  magnitude)
#   dirH = 'R' or 'L'                    (right / left)
#   xxx  = |dx| // 3, clamped 0‑255      (horizontal magnitude)
#
# If no face detected → "N000N000"

import serial
import time
from eye_detection_model import EyeDetectionModel


class ArduinoPWMSerialOutput:
    """
    Arduino PWM serial output controller for eye tracking feedback.
    Sends directional LED control packets based on eye position.
    """

    def __init__(self, serial_port, baud_rate=9600):
        """
        Initialize Arduino serial connection.

        Args:
            serial_port (str): Arduino serial port path
            baud_rate (int): Serial communication baud rate
        """
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.arduino = serial.Serial(serial_port, baud_rate, timeout=1)
        time.sleep(2)  # Allow board reset

        # Initialize eye detection model
        self.eye_model = EyeDetectionModel()

        # Frame dimensions (should match eye detection model)
        self.frame_w = self.eye_model.frame_w
        self.frame_h = self.eye_model.frame_h

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

        dir_v = "U" if dy <= 0 else "D"
        dir_h = "L" if dx <= 0 else "R"

        dist_v = min(abs(dy) // 2, 255)  # divide Y by 2
        dist_h = min(abs(dx) // 3, 255)  # divide X by 3

        return f"{dir_v}{dist_v:03d}{dir_h}{dist_h:03d}"

    def send_packet(self, packet):
        """
        Send packet to Arduino.

        Args:
            packet (str): 8-character packet to send
        """
        self.arduino.write(packet.encode())

    def run(self, debug_display=True):
        """
        Main loop for eye tracking and Arduino communication.

        Args:
            debug_display (bool): Whether to show debug visualization
        """
        try:
            while True:
                # Get eye location from model
                eye_x, eye_y = self.eye_model.get_eye_location(
                    debug_display=debug_display
                )

                if eye_x is not None and eye_y is not None:
                    # Calculate and send directional packet
                    packet = self._calculate_directional_packet(eye_x, eye_y)
                else:
                    # No eye detected
                    packet = "N000N000"

                # Send packet to Arduino
                self.send_packet(packet)

                # Check for quit command (only if debug display is enabled)
                if debug_display:
                    import cv2

                    if cv2.waitKey(1) & 0xFF == ord("q"):
                        break

        except KeyboardInterrupt:
            print("Interrupted by user")
        finally:
            self.cleanup()

    def cleanup(self):
        """Clean up resources."""
        self.eye_model.cleanup()
        self.arduino.close()
        print("Cleanup complete")


def main():
    """Main function to run the eye tracking system."""
    try:
        # Create and run the Arduino PWM serial output controller
        controller = ArduinoPWMSerialOutput("/dev/cu.usbmodemF412FA6399F42")
        controller.run(debug_display=True)
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()

