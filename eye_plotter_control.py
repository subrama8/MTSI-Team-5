import cv2
import mediapipe as mp
import numpy as np
import serial
import time

# === SERIAL SETUP ===
ser = serial.Serial('COM5', 9600)  # Replace with correct port
time.sleep(2)

cap = cv2.VideoCapture(0)

mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=False, max_num_faces=1)

LEFT_EYE_LANDMARKS = [33, 133, 160, 159, 158, 144, 153, 154, 155, 173]

def get_eye_center(landmarks, shape, indices):
    h, w = shape
    points = np.array([[int(landmarks[i].x * w), int(landmarks[i].y * h)] for i in indices])
    if len(points) >= 5:
        ellipse = cv2.fitEllipse(points)
        return (int(ellipse[0][0]), int(ellipse[0][1]))
    return tuple(np.mean(points, axis=0).astype(int))

def compute_offset(center, shape, deadzone=20):
    cx, cy = shape[1] // 2, shape[0] // 2
    dx, dy = center[0] - cx, center[1] - cy
    dx = 0 if abs(dx) < deadzone else dx
    dy = 0 if abs(dy) < deadzone else dy
    return int(dx / 10), int(dy / 10)

while True:
    ret, frame = cap.read()
    if not ret:
        continue

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(rgb)

    if results.multi_face_landmarks:
        lm = results.multi_face_landmarks[0].landmark
        eye_center = get_eye_center(lm, frame.shape[:2], LEFT_EYE_LANDMARKS)
        dx, dy = compute_offset(eye_center, frame.shape[:2])

        cmd = f"MOVE X{dx} Y{dy}\n"
        ser.write(cmd.encode())

        cv2.circle(frame, eye_center, 5, (0, 0, 255), -1)
        cv2.putText(frame, f"Eye: {eye_center}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    else:
        ser.write(b"MOVE X0 Y0\n")  # Stop if no face

    cv2.imshow("Eye Tracker", frame)
    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
