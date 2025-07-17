#!/usr/bin/env python3
# eye_tracker_tx_dual_axis_scaled.py
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

import cv2
import mediapipe as mp
import numpy as np
import serial
import time

# ─── Arduino serial port ───────────────────────────────────────────────────
arduino = serial.Serial("/dev/cu.usbmodemF412FA6399F42", 9600, timeout=1)
time.sleep(2)  # allow board reset

# ─── MediaPipe face mesh ───────────────────────────────────────────────────
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(max_num_faces=1)

LEFT_EYE_LM = [33, 133, 160, 159, 158, 144, 153, 154, 155, 173]


def eye_center(landmarks, img_shape, idxs):
    h, w = img_shape
    pts = np.array([[int(landmarks[i].x * w), int(landmarks[i].y * h)] for i in idxs])
    if len(pts) >= 5:
        (cx, cy), _axes, _ = cv2.fitEllipse(pts)
        return int(cx), int(cy)
    return tuple(np.mean(pts, axis=0).astype(int))


# ─── camera init ───────────────────────────────────────────────────────────
FRAME_W, FRAME_H = 640, 480
cap = cv2.VideoCapture(1, cv2.CAP_AVFOUNDATION)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_W)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_H)

# ─── main loop ─────────────────────────────────────────────────────────────
while True:
    ok, frame = cap.read()
    if not ok:
        break

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    res = face_mesh.process(rgb)

    packet = "N000N000"  # default when no face

    if res.multi_face_landmarks:
        lm = res.multi_face_landmarks[0].landmark
        ex, ey = eye_center(lm, (FRAME_H, FRAME_W), LEFT_EYE_LM)

        # ---------- (optional) draw landmarks for debugging -------------
        for i in LEFT_EYE_LM:
            px = int(lm[i].x * FRAME_W)
            py = int(lm[i].y * FRAME_H)
            cv2.circle(frame, (px, py), 2, (0, 255, 0), -1)
        cv2.circle(frame, (ex, ey), 5, (0, 0, 255), -1)

        # ---------- compute deltas with scaling -------------------------
        dx = ex - FRAME_W // 2  # + = right,  - = left
        dy = ey - FRAME_H // 2  # + = down,   - = up

        dir_v = "U" if dy <= 0 else "D"
        dir_h = "L" if dx <= 0 else "R"

        dist_v = min(abs(dy) // 2, 255)  # divide Y by 2
        dist_h = min(abs(dx) // 3, 255)  # divide X by 3

        packet = f"{dir_v}{dist_v:03d}{dir_h}{dist_h:03d}"

    # ─── send & display ──────────────────────────────────────────────────
    arduino.write(packet.encode())

    cv2.imshow("Eye Tracker", frame)
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

# ─── cleanup ──────────────────────────────────────────────────────────────
cap.release()
cv2.destroyAllWindows()
arduino.close()
