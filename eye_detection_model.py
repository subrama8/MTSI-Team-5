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
    
    def __init__(self, frame_width=640, frame_height=480, camera_index=1):
        """
        Initialize the eye detection model.
        
        Args:
            frame_width (int): Camera frame width
            frame_height (int): Camera frame height
            camera_index (int): Camera index for cv2.VideoCapture
        """
        self.frame_w = frame_width
        self.frame_h = frame_height
        
        # MediaPipe face mesh initialization
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(max_num_faces=1)
        
        # Left eye landmark indices
        self.left_eye_lm = [33, 133, 160, 159, 158, 144, 153, 154, 155, 173]
        
        # Camera initialization
        self.cap = cv2.VideoCapture(camera_index, cv2.CAP_AVFOUNDATION)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.frame_w)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.frame_h)
        
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
        pts = np.array([[int(landmarks[i].x * w), int(landmarks[i].y * h)] for i in idxs])
        if len(pts) >= 5:
            (cx, cy), _axes, _ = cv2.fitEllipse(pts)
            return int(cx), int(cy)
        return tuple(np.mean(pts, axis=0).astype(int))
    
    def get_eye_location(self, debug_display=True):
        """
        Get the current eye location from camera frame.
        
        Args:
            debug_display (bool): Whether to show debug visualization
            
        Returns:
            tuple: (x, y) coordinates of eye center, or (None, None) if no eye detected
        """
        ok, frame = self.cap.read()
        if not ok:
            return None, None
            
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = self.face_mesh.process(rgb)
        
        if res.multi_face_landmarks:
            lm = res.multi_face_landmarks[0].landmark
            ex, ey = self._eye_center(lm, (self.frame_h, self.frame_w), self.left_eye_lm)
            
            if debug_display:
                # Draw landmarks for debugging
                for i in self.left_eye_lm:
                    px = int(lm[i].x * self.frame_w)
                    py = int(lm[i].y * self.frame_h)
                    cv2.circle(frame, (px, py), 2, (0, 255, 0), -1)
                cv2.circle(frame, (ex, ey), 5, (0, 0, 255), -1)
                
                cv2.imshow("Eye Tracker", frame)
                cv2.waitKey(1)
            
            return ex, ey
        
        if debug_display:
            cv2.imshow("Eye Tracker", frame)
            cv2.waitKey(1)
            
        return None, None
    
    def cleanup(self):
        """Release camera and close windows."""
        self.cap.release()
        cv2.destroyAllWindows()
