#!/usr/bin/env python3
# camera_http_server.py
#
# HTTP Camera Server for iOS App Integration
# Serves MJPEG camera stream over HTTP with eye tracking overlays
#
# Usage:
#   python3 camera_http_server.py
#   
# The server will be accessible at:
#   http://[laptop-ip]:8081/stream.mjpeg

import warnings
warnings.filterwarnings("ignore", category=UserWarning, module="google.protobuf")

import cv2
import threading
import time
import socket
import sys
import signal
import atexit
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from eye_detection_model import EyeDetectionModel

# Global configuration
SERVER_PORT = 8081
CAMERA_INDEX = 1  # External camera
FRAME_WIDTH = 640
FRAME_HEIGHT = 480
REFERENCE_OFFSET_PIXELS = 210  # Pixels above center for target reference point

class CameraStreamHandler(BaseHTTPRequestHandler):
    """HTTP request handler for camera streaming."""
    
    def do_GET(self):
        """Handle GET requests for camera stream."""
        if self.path == '/stream.mjpeg':
            self.send_mjpeg_stream()
        elif self.path == '/status':
            self.send_status()
        elif self.path == '/test':
            self.send_test_image()
        elif self.path == '/':
            self.send_html_viewer()
        else:
            self.send_error(404, "Not Found")
    
    def send_test_image(self):
        """Send a single test JPEG image."""
        self.send_response(200)
        self.send_header('Content-Type', 'image/jpeg')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        if hasattr(self.server, 'camera_server') and self.server.camera_server:
            frame = self.server.camera_server.get_latest_frame()
            if frame is not None:
                ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                if ret:
                    self.wfile.write(buffer.tobytes())
                    return
        
        # Send a simple test pattern if no camera
        import numpy as np
        test_image = np.zeros((240, 320, 3), dtype=np.uint8)
        test_image[60:180, 80:240] = [0, 255, 0]  # Green rectangle
        ret, buffer = cv2.imencode('.jpg', test_image)
        if ret:
            self.wfile.write(buffer.tobytes())
    
    def send_mjpeg_stream(self):
        """Send MJPEG camera stream."""
        self.send_response(200)
        self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=--jpgboundary')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        self.end_headers()
        
        try:
            while True:
                if hasattr(self.server, 'camera_server') and self.server.camera_server:
                    frame = self.server.camera_server.get_latest_frame()
                    if frame is not None:
                        # Encode frame as JPEG
                        ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                        if ret:
                            try:
                                self.wfile.write(b'--jpgboundary\r\n')
                                self.wfile.write(f'Content-Type: image/jpeg\r\n'.encode())
                                self.wfile.write(f'Content-Length: {len(buffer)}\r\n\r\n'.encode())
                                self.wfile.write(buffer.tobytes())
                                self.wfile.write(b'\r\n')
                                self.wfile.flush()
                            except (BrokenPipeError, ConnectionResetError):
                                # Client disconnected - exit gracefully
                                break
                
                time.sleep(1/15)  # 15 FPS for better compatibility
                
        except (BrokenPipeError, ConnectionResetError, OSError) as e:
            # Normal disconnection - don't log as error
            pass
        except Exception as e:
            print(f"Stream error: {e}")
    
    def send_status(self):
        """Send server status as JSON."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        status = {
            "status": "running",
            "camera": "connected" if hasattr(self.server, 'camera_server') and self.server.camera_server else "disconnected",
            "stream_url": f"http://{get_local_ip()}:{SERVER_PORT}/stream.mjpeg"
        }
        
        import json
        self.wfile.write(json.dumps(status).encode())
    
    def send_html_viewer(self):
        """Send a simple HTML viewer for testing."""
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Eye Tracking Camera Stream</title>
            <style>
                body {{ font-family: Arial, sans-serif; text-align: center; background: #f0f0f0; }}
                img {{ max-width: 90%; border: 2px solid #333; border-radius: 10px; }}
                h1 {{ color: #333; }}
            </style>
        </head>
        <body>
            <h1>Eye Tracking Camera Stream</h1>
            <p>Stream URL: <code>http://{get_local_ip()}:{SERVER_PORT}/stream.mjpeg</code></p>
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
            if hasattr(exc_value, 'errno'):
                if exc_value.errno in (errno.ECONNRESET, errno.EPIPE, 54, 32):
                    # Normal mobile disconnection - log minimally
                    print(f"📱 iOS app ({client_address[0]}) disconnected")
                    return
        
        # For unexpected errors, show minimal info
        if exc_type:
            print(f"⚠️ Connection issue with {client_address[0]}: {exc_type.__name__}")
        else:
            print(f"📱 Client {client_address[0]} connection ended")

class CameraStreamServer:
    """Camera stream server with eye tracking integration."""
    
    def __init__(self, camera_index=CAMERA_INDEX, deadzone_pixels=10):
        """Initialize camera server."""
        self.camera_index = camera_index
        self.deadzone_pixels = deadzone_pixels
        self.latest_frame = None
        self.frame_lock = threading.Lock()
        self.running = False
        self.capture_thread = None
        self.eye_model = None
        
        # Initialize eye detection model with better error handling
        print(f"🎥 Attempting to initialize camera (index {camera_index})...")
        
        # First, let's check available cameras
        self._check_available_cameras()
        
        try:
            self.eye_model = EyeDetectionModel(
                frame_width=FRAME_WIDTH,
                frame_height=FRAME_HEIGHT,
                camera_index=camera_index,
                deadzone_pixels=deadzone_pixels,
                reference_offset_pixels=REFERENCE_OFFSET_PIXELS
            )
            print("✅ Eye detection model initialized successfully")
        except Exception as e:
            print(f"❌ Failed to initialize eye detection model: {e}")
            print(f"💡 Troubleshooting tips:")
            print(f"   - Camera index {camera_index} might not exist")
            print(f"   - Try camera index 0 (built-in camera)")
            print(f"   - Close other apps using the camera")
            print(f"   - Check camera permissions in System Preferences")
            print(f"   - Restart the terminal/script")
            raise
    
    def _check_available_cameras(self):
        """Check which camera indices are available."""
        print("🔍 Checking available cameras...")
        available_cameras = []
        
        for i in range(5):  # Check indices 0-4
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                ret, frame = cap.read()
                if ret and frame is not None:
                    available_cameras.append(i)
                    print(f"   ✅ Camera {i}: Available ({frame.shape[1]}x{frame.shape[0]})")
                else:
                    print(f"   ❌ Camera {i}: Can't read frames")
                cap.release()
            else:
                print(f"   ❌ Camera {i}: Not available")
        
        if not available_cameras:
            print("⚠️ No cameras found! Make sure:")
            print("   - Camera is connected")
            print("   - No other apps are using it")
            print("   - Camera permissions are granted")
        else:
            print(f"📹 Available cameras: {available_cameras}")
    
    def start(self):
        """Start camera capture."""
        if self.running:
            return
            
        self.running = True
        self.capture_thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.capture_thread.start()
        print("✓ Camera capture started")
    
    def stop(self):
        """Stop camera capture."""
        self.running = False
        if self.capture_thread:
            self.capture_thread.join(timeout=2)
        if self.eye_model:
            self.eye_model.cleanup()
        print("✓ Camera capture stopped")
    
    def get_latest_frame(self):
        """Get the latest camera frame."""
        with self.frame_lock:
            return self.latest_frame.copy() if self.latest_frame is not None else None
    
    def _capture_loop(self):
        """Main camera capture loop."""
        frame_count = 0
        last_eye_status = None
        consecutive_errors = 0
        max_consecutive_errors = 10
        
        print("🎬 Starting camera capture loop...")
        
        try:
            while self.running:
                frame_count += 1
                
                try:
                    # Get eye location and frame with detailed error handling
                    eye_x, eye_y = None, None
                    frame = None
                    
                    try:
                        eye_x, eye_y = self.eye_model.get_eye_location(debug_display=False)
                        consecutive_errors = 0  # Reset error counter on success
                    except Exception as e:
                        consecutive_errors += 1
                        if consecutive_errors <= 3:  # Only log first few errors
                            print(f"⚠️ Error getting eye location (attempt {consecutive_errors}): {e}")
                        
                        if consecutive_errors >= max_consecutive_errors:
                            print(f"❌ Too many consecutive errors ({consecutive_errors}), stopping capture")
                            break
                    
                    # Get the current frame for streaming
                    try:
                        frame = self.eye_model.get_current_frame()
                    except Exception as e:
                        print(f"⚠️ Error getting current frame: {e}")
                        time.sleep(1/30)
                        continue
                    
                    if frame is None:
                        if frame_count % 30 == 0:  # Log every 30 frames
                            print(f"⚠️ No frame available at frame {frame_count}")
                        time.sleep(1/30)
                        continue
                    
                    # Create annotated frame for streaming
                    try:
                        annotated_frame = frame.copy()
                    except Exception as e:
                        print(f"⚠️ Error copying frame: {e}")
                        continue
                    
                    # Add eye tracking visualizations
                    if eye_x is not None and eye_y is not None:
                        # Draw eye center
                        cv2.circle(annotated_frame, (int(eye_x), int(eye_y)), 5, (0, 255, 0), -1)
                        
                        # Calculate directional packet info
                        packet = self._calculate_directional_packet(eye_x, eye_y)
                        status_text = f"Eye Detected - {packet}"
                        if last_eye_status != "detected":
                            last_eye_status = "detected"
                    else:
                        packet = "N000N000"
                        status_text = "No Eye Detected"
                        if last_eye_status != "not_detected":
                            last_eye_status = "not_detected"
                    
                    # Add reference point and deadzone visualization
                    ref_x = FRAME_WIDTH // 2
                    ref_y = FRAME_HEIGHT // 2 - REFERENCE_OFFSET_PIXELS
                    cv2.circle(annotated_frame, (ref_x, ref_y), 3, (255, 0, 0), -1)  # Blue reference point
                    cv2.circle(annotated_frame, (ref_x, ref_y), self.deadzone_pixels, (255, 0, 0), 2)  # Blue deadzone circle
                    
                    # Add text overlay
                    cv2.putText(annotated_frame, status_text, (10, 30), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                    cv2.putText(annotated_frame, f"Frame: {frame_count} | iOS Stream Active", (10, 60), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                
                    # Update latest frame for streaming
                    with self.frame_lock:
                        self.latest_frame = annotated_frame
                    
                    # Show local preview window (disabled due to macOS OpenCV issues)
                    # try:
                    #     cv2.imshow('Camera Server Preview', annotated_frame)
                    #     key = cv2.waitKey(1) & 0xFF
                    #     if key == ord('q'):
                    #         print("Local preview window closed")
                    #         self.running = False
                    #         break
                    # except Exception as e:
                    #     print(f"⚠️ Error showing preview window: {e}")
                    
                    # Show frame info instead of preview window
                    if frame_count % 30 == 0:  # Every 30 frames (1 second at 30fps)
                        print(f"📸 Frame {frame_count}: {status_text}")
                    
                    time.sleep(1/30)  # 30 FPS
                
                except Exception as e:
                    consecutive_errors += 1
                    if consecutive_errors <= 3:
                        print(f"⚠️ Error in capture loop iteration {frame_count}: {e}")
                    
                    if consecutive_errors >= max_consecutive_errors:
                        print(f"❌ Too many consecutive errors in capture loop, stopping")
                        break
                    
                    time.sleep(1/30)  # Wait before retrying
                
        except Exception as e:
            print(f"❌ Fatal camera capture error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            print("🎬 Camera capture loop ending...")
            try:
                cv2.destroyAllWindows()
            except:
                pass
    
    def _calculate_directional_packet(self, eye_x, eye_y):
        """Calculate directional packet from eye coordinates."""
        # Reference point is REFERENCE_OFFSET_PIXELS above center
        reference_x = FRAME_WIDTH // 2
        reference_y = FRAME_HEIGHT // 2 - REFERENCE_OFFSET_PIXELS
        
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

def main():
    """Main function to run the camera HTTP server."""
    import sys
    
    print("🚀 Eye Tracking Camera HTTP Server")
    print("=" * 40)
    
    # Allow camera index to be specified as command line argument
    camera_index = CAMERA_INDEX
    if len(sys.argv) > 1:
        try:
            camera_index = int(sys.argv[1])
            print(f"📹 Using camera index {camera_index} from command line")
        except ValueError:
            print(f"⚠️ Invalid camera index '{sys.argv[1]}', using default: {CAMERA_INDEX}")
    else:
        print(f"📹 Using default camera index: {CAMERA_INDEX}")
        print(f"💡 To use different camera: python3 camera_http_server.py <camera_index>")
    
    camera_server = None
    http_server = None
    server_thread = None
    shutdown_event = threading.Event()
    
    def cleanup():
        """Cleanup function."""
        print("\n🧹 Cleaning up...")
        shutdown_event.set()  # Signal shutdown
        
        if http_server:
            try:
                http_server.shutdown()
                http_server.server_close()
                print("✓ HTTP server stopped")
            except Exception as e:
                print(f"⚠️ Error stopping HTTP server: {e}")
        
        if server_thread and server_thread.is_alive():
            server_thread.join(timeout=2)
            
        if camera_server:
            camera_server.stop()
            
        print("✅ Cleanup complete")
    
    def signal_handler(signum, frame):
        """Handle termination signals."""
        print(f"\n🛑 Received signal {signum}, shutting down...")
        cleanup()
        sys.exit(0)
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    atexit.register(cleanup)
    
    try:
        # Initialize camera server with specified camera index
        camera_server = CameraStreamServer(camera_index=camera_index)
        camera_server.start()
        
        # Initialize HTTP server
        server_address = ('', SERVER_PORT)
        http_server = ThreadingHTTPServer(server_address, CameraStreamHandler)
        http_server.camera_server = camera_server
        http_server.timeout = 1  # Add timeout to make server responsive
        
        local_ip = get_local_ip()
        print(f"✓ Camera server started")
        print(f"🌐 Server running at: http://{local_ip}:{SERVER_PORT}")
        print(f"📺 Stream URL: http://{local_ip}:{SERVER_PORT}/stream.mjpeg")
        print(f"📊 Status URL: http://{local_ip}:{SERVER_PORT}/status")
        print("\nPress Ctrl+C to stop")
        
        # Start HTTP server in a separate thread
        server_thread = threading.Thread(target=http_server.serve_forever, daemon=True)
        server_thread.start()
        
        # Main thread waits for shutdown signal
        try:
            while not shutdown_event.is_set():
                shutdown_event.wait(1)  # Check every second
        except KeyboardInterrupt:
            print("\n🛑 Keyboard interrupt received")
            
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Server error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cleanup()

if __name__ == "__main__":
    main()