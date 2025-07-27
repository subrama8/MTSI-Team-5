#!/usr/bin/env python3
# serial_output_camera_http_server.py
#
# Unified Eye Tracking System with Arduino Control and iOS Camera Streaming
# Combines functionality from arduino_pwm_serial_output.py and camera_http_server.py
#
# Features:
# - Real-time eye tracking with MediaPipe
# - Arduino serial communication for LED/motor control
# - Arduino WiFi communication for plotter control
# - HTTP camera server for iOS app streaming
# - MJPEG stream with eye tracking overlays
#
# Usage:
#   python3 serial_output_camera_http_server.py
#
# Endpoints:
#   http://[laptop-ip]:8081/stream.mjpeg  - Camera stream for iOS
#   http://[laptop-ip]:8081/status        - Server status

import warnings

warnings.filterwarnings("ignore", category=UserWarning, module="google.protobuf")

import serial
import serial.tools.list_ports
import time
import sys
import threading
import atexit
import signal
import requests
import socket
import cv2
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from eye_detection_model import EyeDetectionModel

# Global configuration
REFERENCE_OFFSET_PIXELS = 220  # Pixels above center for target reference point
SERVER_PORT = 8081  # HTTP server port for iOS app
CAMERA_INDEX = 1  # External camera
FRAME_WIDTH = 640
FRAME_HEIGHT = 480


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
        pass  # Silently handle WiFi check failures
    return None


def get_local_ip():
    """Get the local IP address of this machine."""
    try:
        # Connect to a remote address to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return "127.0.0.1"


class CameraStreamHandler(BaseHTTPRequestHandler):
    """HTTP request handler for camera streaming."""

    def do_GET(self):
        """Handle GET requests for camera stream."""
        if self.path == "/stream.mjpeg":
            self.send_mjpeg_stream()
        elif self.path == "/status":
            self.send_status()
        elif self.path == "/test":
            self.send_test_image()
        elif self.path == "/":
            self.send_html_viewer()
        else:
            self.send_error(404, "Not Found")

    def send_test_image(self):
        """Send a single test JPEG image."""
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        if (
            hasattr(self.server, "unified_controller")
            and self.server.unified_controller
        ):
            frame = self.server.unified_controller.get_latest_annotated_frame()
            if frame is not None:
                ret, buffer = cv2.imencode(
                    ".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85]
                )
                if ret:
                    self.wfile.write(buffer.tobytes())
                    return

        # Send a simple test pattern if no camera
        import numpy as np

        test_image = np.zeros((240, 320, 3), dtype=np.uint8)
        test_image[60:180, 80:240] = [0, 255, 0]  # Green rectangle
        ret, buffer = cv2.imencode(".jpg", test_image)
        if ret:
            self.wfile.write(buffer.tobytes())

    def send_mjpeg_stream(self):
        """Send MJPEG camera stream."""
        self.send_response(200)
        self.send_header(
            "Content-Type", "multipart/x-mixed-replace; boundary=--jpgboundary"
        )
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Connection", "close")
        self.end_headers()

        try:
            while True:
                if (
                    hasattr(self.server, "unified_controller")
                    and self.server.unified_controller
                ):
                    frame = self.server.unified_controller.get_latest_annotated_frame()
                    if frame is not None:
                        # Encode frame as JPEG
                        ret, buffer = cv2.imencode(
                            ".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85]
                        )
                        if ret:
                            try:
                                self.wfile.write(b"--jpgboundary\r\n")
                                self.wfile.write(
                                    f"Content-Type: image/jpeg\r\n".encode()
                                )
                                self.wfile.write(
                                    f"Content-Length: {len(buffer)}\r\n\r\n".encode()
                                )
                                self.wfile.write(buffer.tobytes())
                                self.wfile.write(b"\r\n")
                                self.wfile.flush()
                            except (BrokenPipeError, ConnectionResetError):
                                # Client disconnected - exit gracefully
                                break

                time.sleep(1 / 15)  # 15 FPS for better compatibility

        except (BrokenPipeError, ConnectionResetError, OSError) as e:
            # Normal disconnection - don't log as error
            pass
        except Exception as e:
            print(f"Stream error: {e}")

    def send_status(self):
        """Send server status as JSON."""
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        controller = getattr(self.server, "unified_controller", None)
        status = {
            "status": "running",
            "camera": (
                "connected" if controller and controller.eye_model else "disconnected"
            ),
            "arduino_serial": (
                "connected" if controller and controller.arduino else "disconnected"
            ),
            "arduino_wifi": (
                "connected"
                if controller and controller.wifi_enabled
                else "disconnected"
            ),
            "plotter_enabled": controller.plotter_enabled if controller else False,
            "stream_url": f"http://{get_local_ip()}:{SERVER_PORT}/stream.mjpeg",
        }

        import json

        self.wfile.write(json.dumps(status).encode())

    def send_html_viewer(self):
        """Send a simple HTML viewer for testing."""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()

        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Unified Eye Tracking System</title>
            <style>
                body {{ font-family: Arial, sans-serif; text-align: center; background: #f0f0f0; }}
                img {{ max-width: 90%; border: 2px solid #333; border-radius: 10px; }}
                h1 {{ color: #333; }}
                .status {{ margin: 20px; padding: 10px; background: #e0e0e0; border-radius: 5px; }}
            </style>
        </head>
        <body>
            <h1>Unified Eye Tracking System</h1>
            <div class="status">
                <p>Stream URL: <code>http://{get_local_ip()}:{SERVER_PORT}/stream.mjpeg</code></p>
                <p>Status URL: <code>http://{get_local_ip()}:{SERVER_PORT}/status</code></p>
            </div>
            <img src="/stream.mjpeg" alt="Camera Stream">
        </body>
        </html>
        """
        self.wfile.write(html.encode())

    def log_message(self, format, *args):
        """Override to reduce HTTP request logging."""
        pass  # Suppress HTTP request logs


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    """Threading HTTP server for handling multiple connections."""

    allow_reuse_address = True
    daemon_threads = True

    def handle_error(self, request, client_address):
        """Handle network errors gracefully without crashing."""
        import sys
        import errno

        # Get the actual exception info
        exc_type, exc_value, exc_traceback = sys.exc_info()

        # Handle common network errors silently
        if exc_type in (ConnectionResetError, BrokenPipeError, OSError):
            if hasattr(exc_value, "errno"):
                if exc_value.errno in (errno.ECONNRESET, errno.EPIPE, 54, 32):
                    # Normal mobile disconnection - log minimally
                    print(f"📱 iOS app ({client_address[0]}) disconnected")
                    return

        # For unexpected errors, show minimal info
        if exc_type:
            print(f"⚠️ Connection issue with {client_address[0]}: {exc_type.__name__}")
        else:
            print(f"📱 Client {client_address[0]} connection ended")


class UnifiedEyeTrackingController:
    """
    Unified controller that combines Arduino communication and HTTP camera streaming.
    Handles eye tracking, serial communication, WiFi communication, and camera streaming.
    """

    def __init__(
        self,
        serial_port=None,
        baud_rate=115200,
        deadzone_pixels=10,
        arduino_ip="192.168.1.60",
        arduino_port=8080,
    ):
        """
        Initialize unified eye tracking controller.

        Args:
            serial_port (str): Arduino serial port path (None if no Arduino)
            baud_rate (int): Serial communication baud rate
            deadzone_pixels (int): Deadzone radius in pixels around frame center
            arduino_ip (str): Arduino WiFi IP address
            arduino_port (int): Arduino WiFi server port
        """
        print(f"🚀 Initializing Unified Eye Tracking System...")
        print("=" * 50)

        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.deadzone_pixels = deadzone_pixels
        self.arduino = None

        # WiFi communication setup
        self.arduino_ip = arduino_ip
        self.arduino_port = arduino_port
        self.wifi_enabled = False
        self.plotter_enabled = False

        # Camera streaming
        self.latest_annotated_frame = None
        self.frame_lock = threading.Lock()

        # Arduino serial setup
        if serial_port:
            print(f"🔌 Serial port: {serial_port}, baud rate: {baud_rate}")
            try:
                self.arduino = serial.Serial(serial_port, baud_rate, timeout=1)
                print("✅ Arduino serial connection established")
                time.sleep(2)  # Allow board reset
            except Exception as e:
                print(f"❌ Failed to connect to Arduino: {e}")
                print("📺 Continuing with camera streaming only")
                self.arduino = None
        else:
            print("📺 No Arduino serial port specified")

        # Check WiFi connection to Arduino
        print(f"🌐 Checking Arduino WiFi connection at {arduino_ip}:{arduino_port}")
        wifi_status = check_arduino_wifi_status(arduino_ip, arduino_port)
        if wifi_status:
            self.wifi_enabled = True
            self.plotter_enabled = wifi_status.get("enabled", False)
            print(
                f"✅ Arduino WiFi connected - Plotter {'enabled' if self.plotter_enabled else 'disabled'}"
            )
        else:
            print("⚠️ Arduino WiFi not accessible")

        # Initialize eye detection model
        try:
            self.eye_model = EyeDetectionModel(
                frame_width=FRAME_WIDTH,
                frame_height=FRAME_HEIGHT,
                camera_index=CAMERA_INDEX,
                deadzone_pixels=self.deadzone_pixels,
                reference_offset_pixels=REFERENCE_OFFSET_PIXELS,
            )
            print("✅ Eye detection model initialized")
        except Exception as e:
            print(f"❌ Failed to initialize eye detection model: {e}")
            raise

        # Frame dimensions (should match eye detection model)
        self.frame_w = self.eye_model.frame_w
        self.frame_h = self.eye_model.frame_h
        print(f"📹 Camera resolution: {self.frame_w}x{self.frame_h}")

        # Cleanup tracking
        self._cleanup_called = False
        self._cleanup_lock = threading.Lock()

        # Register cleanup handlers
        atexit.register(self.cleanup)
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

        print("✅ Unified eye tracking system ready!")
        print(
            f"🌐 HTTP camera server will be available at: http://{get_local_ip()}:{SERVER_PORT}"
        )

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

    def send_packet_to_arduino(self, packet):
        """
        Send packet to Arduino via serial.

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
                    print("✅ Serial reconnection successful")
                except Exception as reconnect_error:
                    print(f"❌ Serial reconnection failed: {reconnect_error}")
                    print("📺 Continuing without serial communication")
                    self.arduino = None

    def check_plotter_status(self):
        """Check and update plotter status via WiFi."""
        if self.wifi_enabled:
            try:
                status = check_arduino_wifi_status(
                    self.arduino_ip, self.arduino_port, timeout=1
                )
                if status:
                    old_status = self.plotter_enabled
                    self.plotter_enabled = status.get("enabled", False)
                    if old_status != self.plotter_enabled:
                        print(
                            f"📊 Plotter status changed: {'enabled' if self.plotter_enabled else 'disabled'}"
                        )
                    return True
            except Exception as e:
                pass  # Silently handle status check failures
        return False

    def get_latest_annotated_frame(self):
        """Get the latest annotated camera frame for streaming."""
        with self.frame_lock:
            return (
                self.latest_annotated_frame.copy()
                if self.latest_annotated_frame is not None
                else None
            )

    def run(self, debug_display=True):
        """
        Main loop for unified eye tracking, Arduino communication, and camera streaming.

        Args:
            debug_display (bool): Whether to show local debug visualization
        """
        print("\n🎯 Starting unified eye tracking loop...")
        print("📱 iOS app will auto-discover camera stream")
        print("🤖 Arduino communication active")
        print("Press 'q' in camera window or Ctrl+C to stop")
        print("-" * 50)

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

                # Calculate packet
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

                # Send packet to Arduino (both serial and WiFi are handled by Arduino)
                self.send_packet_to_arduino(packet)

                # Create annotated frame for iOS streaming
                frame = self.eye_model.get_current_frame()
                if frame is not None:
                    annotated_frame = frame.copy()

                    # Add eye tracking visualizations
                    if eye_x is not None and eye_y is not None:
                        # Draw eye center
                        cv2.circle(
                            annotated_frame,
                            (int(eye_x), int(eye_y)),
                            5,
                            (0, 255, 0),
                            -1,
                        )
                        status_text = f"Eye Detected - {packet}"
                    else:
                        status_text = "No Eye Detected"

                    # Add reference point and deadzone visualization
                    ref_x = self.frame_w // 2
                    ref_y = self.frame_h // 2 - REFERENCE_OFFSET_PIXELS
                    cv2.circle(
                        annotated_frame, (ref_x, ref_y), 3, (255, 0, 0), -1
                    )  # Blue reference point
                    cv2.circle(
                        annotated_frame,
                        (ref_x, ref_y),
                        self.deadzone_pixels,
                        (255, 0, 0),
                        2,
                    )  # Blue deadzone circle

                    # Add comprehensive status overlay
                    status_lines = [
                        f"Packet: {packet}",
                        f"Frame: {loop_count}",
                        f"Arduino: {'Serial' if self.arduino else 'None'}"
                        + (
                            f" + WiFi {'ON' if self.plotter_enabled else 'OFF'}"
                            if self.wifi_enabled
                            else ""
                        ),
                        f"iOS Stream: Active",
                    ]

                    for i, line in enumerate(status_lines):
                        y_pos = 25 + (i * 20)
                        cv2.putText(
                            annotated_frame,
                            line,
                            (10, y_pos),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.5,
                            (255, 255, 255),
                            1,
                        )

                    # Update frame for streaming
                    with self.frame_lock:
                        self.latest_annotated_frame = annotated_frame

                # Display frame locally if debug is enabled
                if debug_display:
                    try:
                        # Create packet info with comprehensive status
                        status_text = (
                            f"Plotter: {'ON' if self.plotter_enabled else 'OFF'}"
                        )
                        if self.wifi_enabled:
                            status_text += " (WiFi)"
                        elif self.arduino:
                            status_text += " (Serial)"
                        else:
                            status_text += " (No Arduino)"
                        status_text += " | iOS Stream: Active"

                        packet_with_status = f"{packet} | {status_text}"
                        self.eye_model.display_frame_with_packet(
                            packet_with_status, eye_x, eye_y
                        )
                    except Exception as e:
                        print(f"Error displaying camera frame: {e}")

                # Check for quit command (only if debug display is enabled)
                if debug_display:
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
                print("✅ Sent neutral signal to Arduino")
        except Exception as e:
            print(f"⚠️  Error sending neutral signal: {e}")

        # Step 2: Clean up eye model (includes camera and MediaPipe)
        try:
            if hasattr(self, "eye_model") and self.eye_model:
                self.eye_model.cleanup()
                self.eye_model = None
                print("✅ Eye detection model cleaned up")
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
                    print("✅ Arduino connection closed")
                    break
            except Exception as e:
                print(f"⚠️  Arduino close attempt {attempt + 1} failed: {e}")
                time.sleep(0.1)

        if not arduino_closed:
            print("⚠️  Warning: Arduino connection may not have been fully closed")

        # Step 4: Final OpenCV cleanup
        try:
            cv2.destroyAllWindows()
            # Multiple waitKey calls to ensure cleanup
            for _ in range(10):
                cv2.waitKey(1)
            print("✅ Final OpenCV cleanup completed")
        except Exception as e:
            print(f"⚠️  Error in final OpenCV cleanup: {e}")

        # Step 5: Force garbage collection
        try:
            import gc

            gc.collect()
            print("✅ Garbage collection completed")
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
    """Main function to run the unified eye tracking system."""
    print("🚀 Unified Eye Tracking System with iOS Camera Streaming")
    print("=" * 60)

    unified_controller = None
    http_server = None

    def cleanup():
        """Cleanup function."""
        print("\n🧹 Cleaning up servers...")
        if unified_controller:
            unified_controller.cleanup()
        if http_server:
            http_server.shutdown()
        print("✅ Server cleanup complete")

    def signal_handler_main(signum, frame):
        """Handle termination signals in main."""
        print(f"\n🛑 Received signal {signum} in main, cleaning up...")
        cleanup()
        sys.exit(0)

    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler_main)
    signal.signal(signal.SIGTERM, signal_handler_main)
    atexit.register(cleanup)

    try:
        # Automatically detect Arduino port
        arduino_port = find_arduino_port()
        if not arduino_port:
            print(
                f"💡 Available ports: {[port.device for port in serial.tools.list_ports.comports()]}"
            )
            print("📺 No Arduino detected - continuing with camera streaming only")

        # Initialize unified controller
        unified_controller = UnifiedEyeTrackingController(arduino_port)

        # Initialize HTTP server for iOS app
        server_address = ("", SERVER_PORT)
        http_server = ThreadingHTTPServer(server_address, CameraStreamHandler)
        http_server.unified_controller = unified_controller

        # Start HTTP server in background thread
        server_thread = threading.Thread(target=http_server.serve_forever, daemon=True)
        server_thread.start()

        local_ip = get_local_ip()
        print(f"✅ HTTP camera server started at: http://{local_ip}:{SERVER_PORT}")
        print(f"📺 iOS stream URL: http://{local_ip}:{SERVER_PORT}/stream.mjpeg")
        print(f"📊 Status URL: http://{local_ip}:{SERVER_PORT}/status")

        # Run the main eye tracking loop
        unified_controller.run(debug_display=True)

    except KeyboardInterrupt:
        print("\n🛑 Program stopped by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback

        traceback.print_exc()
    finally:
        cleanup()

        # Final system cleanup
        try:
            cv2.destroyAllWindows()
            for _ in range(5):
                cv2.waitKey(1)
        except Exception:
            pass

        print("👋 Unified eye tracking system shutdown complete")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"💥 Fatal error in main: {e}")
        sys.exit(1)
