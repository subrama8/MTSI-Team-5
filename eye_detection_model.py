#!/usr/bin/env python3
# eye_detection_model.py
#
# Eye detection model class for MediaPipe-based eye tracking

import cv2
import mediapipe as mp
import numpy as np
import threading
import time
import atexit


class EyeDetectionModel:
    """
    Eye detection model using MediaPipe Face Mesh with Iris landmarks.
    Provides precise eye center detection from camera frames using iris tracking.
    """

    def __init__(self, frame_width=640, frame_height=480, camera_index=1, deadzone_pixels=10, reference_offset_pixels=200):
        """
        Initialize the eye detection model.

        Args:
            frame_width (int): Camera frame width
            frame_height (int): Camera frame height
            camera_index (int): Camera index for cv2.VideoCapture
            deadzone_pixels (int): Deadzone radius in pixels around frame center
            reference_offset_pixels (int): Pixels above center for target reference point
        """
        self.frame_w = frame_width
        self.frame_h = frame_height
        self.deadzone_pixels = deadzone_pixels
        self.reference_offset_pixels = reference_offset_pixels

        # MediaPipe face mesh initialization with iris landmarks
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,  # Enable iris landmarks
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

        # Iris landmark indices for precise eye center detection
        self.LEFT_IRIS_CENTER = 473  # Left iris center landmark
        self.RIGHT_IRIS_CENTER = 468  # Right iris center landmark
        
        # Iris contour indices for visualization
        self.LEFT_IRIS = [474, 475, 476, 477, 473]
        self.RIGHT_IRIS = [469, 470, 471, 472, 468]
        
        # Eyelid landmark indices for head-position-independent eye center detection
        self.LEFT_EYELID = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]
        self.RIGHT_EYELID = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]

        # Camera initialization with fallback
        self.cap = None
        camera_found = False
        
        # Try external camera first (index 1)
        if camera_index == 1:
            print(f"🎥 Trying external camera (index {camera_index})...")
            self.cap = cv2.VideoCapture(camera_index, cv2.CAP_AVFOUNDATION)
            if self.cap.isOpened():
                ret, test_frame = self.cap.read()
                if ret and test_frame is not None:
                    print("✓ External camera connected and working")
                    camera_found = True
                else:
                    print("⚠️ External camera detected but not working properly")
                    self.cap.release()
                    self.cap = None
            else:
                print("❌ External camera not found")
                self.cap.release()
                self.cap = None
        
        # Fallback to built-in camera (index 0) if external not found
        if not camera_found:
            print("🎥 Trying built-in camera (index 0)...")
            self.cap = cv2.VideoCapture(0, cv2.CAP_AVFOUNDATION)
            if self.cap.isOpened():
                ret, test_frame = self.cap.read()
                if ret and test_frame is not None:
                    print("✓ Built-in camera connected and working")
                    camera_found = True
                else:
                    print("⚠️ Built-in camera detected but not working properly")
                    self.cap.release()
                    self.cap = None
            else:
                print("❌ Built-in camera not found")
                if self.cap:
                    self.cap.release()
                self.cap = None
        
        if not camera_found:
            raise RuntimeError("❌ No working camera found (tried external and built-in)")
        
        # Set camera properties
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.frame_w)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.frame_h)
        
        # Verify final camera settings
        actual_width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        actual_height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"📹 Camera resolution set to: {actual_width}x{actual_height}")

        # Store last frame and packet for display
        self.last_frame = None
        self.last_packet = None
        
        # Eye tracking selection with simple visibility-based switching
        self.active_eye = 'left'  # 'left' or 'right'
        self.last_visibility_check = 0
        self.visibility_check_interval = 1.0  # Check every 1 second
        
        # Eye center calculation mode: 'iris' (pupil-based) or 'eyelid' (head-position-independent)
        self.center_mode = 'eyelid'  # Default to eyelid tracking
        
        # Cleanup tracking
        self._cleanup_called = False
        self._cleanup_lock = threading.Lock()
        
        # Register cleanup on exit
        atexit.register(self.cleanup)


    def _is_eye_visible(self, landmarks, eye_type):
        """
        Simple visibility check for an eye.
        
        Args:
            landmarks: MediaPipe face landmarks
            eye_type (str): 'left' or 'right'
            
        Returns:
            bool: True if eye is visible and trackable, False otherwise
        """
        try:
            if eye_type == 'left':
                center_idx = self.LEFT_IRIS_CENTER
                iris_indices = self.LEFT_IRIS
            else:
                center_idx = self.RIGHT_IRIS_CENTER
                iris_indices = self.RIGHT_IRIS
            
            center = landmarks[center_idx]
            
            
            # For iris landmarks, confidence values are often 0.0, so we primarily use coordinate-based detection
            # If the iris center has reasonable coordinates, assume it's visible
            coords_valid = 0.0 <= center.x <= 1.0 and 0.0 <= center.y <= 1.0
            
            # If coordinates are valid, the eye is visible (MediaPipe wouldn't provide coordinates for invisible eyes)
            if coords_valid:
                return True
            
            # Fallback: Use confidence if coordinates seem invalid
            if hasattr(center, 'presence') and center.presence is not None and center.presence > 0.1:
                return True
            elif hasattr(center, 'visibility') and center.visibility is not None and center.visibility > 0.05:
                return True
            
            return False
                
        except Exception as e:
            return False
    
    def get_eye_location(self, debug_display=True):
        """
        Get the current eye location from camera frame using confidence-based eye selection.

        Args:
            debug_display (bool): Whether to show debug visualization (deprecated - use display_frame_with_packet)

        Returns:
            tuple: (x, y) coordinates of highest confidence eye center, or (None, None) if no eye detected
        """
        if self.cap is None or not self.cap.isOpened():
            return None, None
            
        ok, frame = self.cap.read()
        if not ok or frame is None:
            return None, None

        # Rotate frame by 180 degrees
        frame = cv2.rotate(frame, cv2.ROTATE_180)

        # Store frame for display
        self.last_frame = frame.copy()

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = self.face_mesh.process(rgb)

        if res.multi_face_landmarks:
            lm = res.multi_face_landmarks[0].landmark
            
            # Check if it's time to reevaluate eye visibility
            current_time = time.time()
            if current_time - self.last_visibility_check >= self.visibility_check_interval:
                left_visible = self._is_eye_visible(lm, 'left')
                right_visible = self._is_eye_visible(lm, 'right')
                
                # Simple sticky logic:
                # 1. If current eye is visible, keep using it
                # 2. If current eye not visible but other is, switch
                # 3. If neither visible, we'll return None, None later
                
                if self.active_eye == 'left':
                    if not left_visible and right_visible:
                        self.active_eye = 'right'
                else:  # active_eye == 'right'
                    if not right_visible and left_visible:
                        self.active_eye = 'left'
                
                self.last_visibility_check = current_time
            
            # Final check: if neither eye is currently visible, return None
            current_eye_visible = self._is_eye_visible(lm, self.active_eye)
            if not current_eye_visible:
                return None, None
            
            # Get coordinates from active eye based on tracking mode
            if self.center_mode == 'iris':
                # Use iris center (pupil tracking)
                if self.active_eye == 'left':
                    iris_center = lm[self.LEFT_IRIS_CENTER]
                else:
                    iris_center = lm[self.RIGHT_IRIS_CENTER]
                
                ex = int(iris_center.x * self.frame_w)
                ey = int(iris_center.y * self.frame_h)
            else:
                # Use eyelid center (head-position-independent)
                if self.active_eye == 'left':
                    eyelid_indices = self.LEFT_EYELID
                else:
                    eyelid_indices = self.RIGHT_EYELID
                
                # Calculate average position of all eyelid landmarks
                sum_x = sum(lm[i].x for i in eyelid_indices)
                sum_y = sum(lm[i].y for i in eyelid_indices)
                avg_x = sum_x / len(eyelid_indices)
                avg_y = sum_y / len(eyelid_indices)
                
                ex = int(avg_x * self.frame_w)
                ey = int(avg_y * self.frame_h)

            return ex, ey

        return None, None

    def display_frame_with_packet(self, packet_info, eye_x=None, eye_y=None):
        """
        Display the last captured frame with packet information overlay.

        Args:
            packet_info (str): Packet information to display
            eye_x (int): Optional eye x coordinate for deadzone calculation
            eye_y (int): Optional eye y coordinate for deadzone calculation
        """
        if self.last_frame is not None:
            display_frame = self.last_frame.copy()

            # Re-process the frame to get landmarks for visualization
            rgb = cv2.cvtColor(self.last_frame, cv2.COLOR_BGR2RGB)
            res = self.face_mesh.process(rgb)

            if res.multi_face_landmarks:
                lm = res.multi_face_landmarks[0].landmark
                
                # Get coordinates and visualization based on tracking mode
                if self.center_mode == 'iris':
                    # Iris mode visualization
                    if self.active_eye == 'left':
                        iris_center = lm[self.LEFT_IRIS_CENTER]
                        iris_indices = self.LEFT_IRIS
                        center_color = (0, 0, 255)  # Red for left
                    else:
                        iris_center = lm[self.RIGHT_IRIS_CENTER]
                        iris_indices = self.RIGHT_IRIS
                        center_color = (255, 0, 0)  # Blue for right
                    
                    ex = int(iris_center.x * self.frame_w)
                    ey = int(iris_center.y * self.frame_h)
                    
                    # Draw iris contour
                    for i in iris_indices:
                        px = int(lm[i].x * self.frame_w)
                        py = int(lm[i].y * self.frame_h)
                        cv2.circle(display_frame, (px, py), 2, (0, 255, 0), -1)  # Green iris contour
                else:
                    # Eyelid mode visualization
                    if self.active_eye == 'left':
                        eyelid_indices = self.LEFT_EYELID
                        center_color = (0, 0, 255)  # Red for left
                    else:
                        eyelid_indices = self.RIGHT_EYELID
                        center_color = (255, 0, 0)  # Blue for right
                    
                    # Calculate eyelid center
                    sum_x = sum(lm[i].x for i in eyelid_indices)
                    sum_y = sum(lm[i].y for i in eyelid_indices)
                    avg_x = sum_x / len(eyelid_indices)
                    avg_y = sum_y / len(eyelid_indices)
                    
                    ex = int(avg_x * self.frame_w)
                    ey = int(avg_y * self.frame_h)
                    
                    # Draw eyelid landmarks
                    for i in eyelid_indices:
                        px = int(lm[i].x * self.frame_w)
                        py = int(lm[i].y * self.frame_h)
                        cv2.circle(display_frame, (px, py), 1, (0, 255, 255), -1)  # Yellow eyelid points
                
                # Draw eye center
                cv2.circle(display_frame, (ex, ey), 5, center_color, -1)
                
                # Add tracking mode and active eye indicator text
                mode_text = f"Mode: {self.center_mode.upper()} | Eye: {self.active_eye.upper()}"
                cv2.putText(
                    display_frame,
                    mode_text,
                    (10, self.frame_h - 20),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.6,
                    center_color,
                    2,
                )

            # Draw deadzone circle at reference point
            reference_x = self.frame_w // 2
            reference_y = self.frame_h // 2 - self.reference_offset_pixels
            cv2.circle(
                display_frame, (reference_x, reference_y), 5, (128, 128, 128), 1
            )  # Gray circle

            # Determine packet text color based on deadzone
            text_color = (255, 255, 255)  # Default white
            if eye_x is not None and eye_y is not None:
                # Calculate distance from reference point
                distance = ((eye_x - reference_x) ** 2 + (eye_y - reference_y) ** 2) ** 0.5

                # If within deadzone, use green text
                if distance <= self.deadzone_pixels:
                    text_color = (0, 255, 0)  # Green

            # Add packet info text with appropriate color
            cv2.putText(
                display_frame,
                f"Packet: {packet_info}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                text_color,
                2,
            )

            # Only show window if not in cleanup phase
            if not self._cleanup_called:
                cv2.imshow("Eye Tracker", display_frame)
                cv2.waitKey(1)

    def cleanup(self):
        """Release all resources including camera, MediaPipe, and OpenCV windows."""
        with self._cleanup_lock:
            if self._cleanup_called:
                return
            self._cleanup_called = True
        
        print("🧹 Cleaning up eye detection model...")
        print(f"👁️ Final active eye was: {getattr(self, 'active_eye', 'unknown')}")
        
        # Step 1: Close MediaPipe face mesh
        try:
            if hasattr(self, 'face_mesh') and self.face_mesh is not None:
                self.face_mesh.close()
                self.face_mesh = None
                print("✓ MediaPipe face mesh closed")
        except Exception as e:
            print(f"⚠️  Error closing MediaPipe face mesh: {e}")
        
        # Step 2: Release camera with multiple attempts
        camera_released = False
        for attempt in range(3):
            try:
                if hasattr(self, 'cap') and self.cap is not None:
                    if self.cap.isOpened():
                        self.cap.release()
                    self.cap = None
                    camera_released = True
                    print("✓ Camera released")
                    break
            except Exception as e:
                print(f"⚠️  Camera release attempt {attempt + 1} failed: {e}")
                time.sleep(0.1)  # Brief pause before retry
        
        if not camera_released:
            print("⚠️  Warning: Camera may not have been fully released")
        
        # Step 3: Destroy OpenCV windows with forced cleanup
        try:
            cv2.destroyAllWindows()
            # Multiple waitKey calls to ensure proper cleanup
            for _ in range(5):
                cv2.waitKey(1)
            print("✓ OpenCV windows destroyed")
        except Exception as e:
            print(f"⚠️  Error destroying OpenCV windows: {e}")
        
        # Step 4: Force garbage collection
        try:
            import gc
            gc.collect()
        except Exception as e:
            print(f"⚠️  Error during garbage collection: {e}")
        
        print("✅ Eye detection model cleanup complete")
    
    def __del__(self):
        """Destructor to ensure cleanup on object deletion."""
        try:
            self.cleanup()
        except Exception:
            pass  # Ignore errors during destruction
