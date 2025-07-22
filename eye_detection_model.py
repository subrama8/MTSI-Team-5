#!/usr/bin/env python3
# eye_detection_model.py
#
# Eye detection model class for MediaPipe-based eye tracking

import cv2
import mediapipe as mp
import numpy as np


class EyeDetectionModel:
    """
    Eye detection model using MediaPipe Face Mesh.
    Provides eye center detection from camera frames.
    """

    def __init__(self, frame_width=640, frame_height=480, camera_index=1, deadzone_pixels=10):
        """
        Initialize the eye detection model.

        Args:
            frame_width (int): Camera frame width
            frame_height (int): Camera frame height
            camera_index (int): Camera index for cv2.VideoCapture
            deadzone_pixels (int): Deadzone radius in pixels around frame center
        """
        self.frame_w = frame_width
        self.frame_h = frame_height
        self.deadzone_pixels = deadzone_pixels

        # MediaPipe face mesh initialization
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(max_num_faces=1)

        # Left eye landmark indices
        self.left_eye_lm = [33, 133, 160, 159, 158, 144, 153, 154, 155, 173]

        # Eye Aspect Ratio (EAR) landmark indices for left eye
        # Vertical landmarks: top and bottom of eye
        self.left_eye_vertical = [159, 145, 158, 153]  # Top-bottom pairs
        # Horizontal landmarks: corners of eye
        self.left_eye_horizontal = [33, 133]  # Left-right corners

        # Camera initialization
        self.cap = cv2.VideoCapture(camera_index, cv2.CAP_AVFOUNDATION)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.frame_w)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.frame_h)

        # Store last frame and packet for display
        self.last_frame = None
        self.last_packet = None

    def _eye_center(self, landmarks, img_shape, idxs):
        """
        Calculate eye center from landmarks.

        Args:
            landmarks: MediaPipe face landmarks
            img_shape: Image shape (height, width)
            idxs: List of landmark indices for eye

        Returns:
            tuple: (x, y) coordinates of eye center
        """
        h, w = img_shape
        pts = np.array(
            [[int(landmarks[i].x * w), int(landmarks[i].y * h)] for i in idxs]
        )
        if len(pts) >= 5:
            (cx, cy), _axes, _ = cv2.fitEllipse(pts)
            return int(cx), int(cy)
        return tuple(np.mean(pts, axis=0).astype(int))

    def get_eye_location(self, debug_display=True):
        """
        Get the current eye location from camera frame.

        Args:
            debug_display (bool): Whether to show debug visualization (deprecated - use display_frame_with_packet)

        Returns:
            tuple: (x, y) coordinates of eye center, or (None, None) if no eye detected
        """
        ok, frame = self.cap.read()
        if not ok:
            return None, None

        # Store frame for display
        self.last_frame = frame.copy()

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = self.face_mesh.process(rgb)

        if res.multi_face_landmarks:
            lm = res.multi_face_landmarks[0].landmark
            ex, ey = self._eye_center(
                lm, (self.frame_h, self.frame_w), self.left_eye_lm
            )

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
                ex, ey = self._eye_center(
                    lm, (self.frame_h, self.frame_w), self.left_eye_lm
                )

                # Draw landmarks for debugging
                for i in self.left_eye_lm:
                    px = int(lm[i].x * self.frame_w)
                    py = int(lm[i].y * self.frame_h)
                    cv2.circle(display_frame, (px, py), 2, (0, 255, 0), -1)
                cv2.circle(display_frame, (ex, ey), 5, (0, 0, 255), -1)

            # Draw deadzone circle at center
            center_x = self.frame_w // 2
            center_y = self.frame_h // 2
            cv2.circle(
                display_frame, (center_x, center_y), 5, (128, 128, 128), 1
            )  # Gray circle

            # Determine packet text color based on deadzone
            text_color = (255, 255, 255)  # Default white
            if eye_x is not None and eye_y is not None:
                # Calculate distance from center
                distance = ((eye_x - center_x) ** 2 + (eye_y - center_y) ** 2) ** 0.5

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

            cv2.imshow("Eye Tracker", display_frame)
            cv2.waitKey(1)

    def cleanup(self):
        """Release camera and close windows."""
        try:
            if hasattr(self, 'cap') and self.cap is not None:
                if self.cap.isOpened():
                    self.cap.release()
        except Exception as e:
            print(f"Error releasing camera: {e}")
        
        try:
            cv2.destroyAllWindows()
            # Give OpenCV time to properly destroy windows
            cv2.waitKey(1)
        except Exception as e:
            print(f"Error destroying OpenCV windows: {e}")
