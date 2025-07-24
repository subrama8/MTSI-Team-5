#include <Arduino.h>

const uint8_t EN1  = 9;
const uint8_t IN1A = 12;
const uint8_t IN1B = 13;

const uint8_t EN2  = 3;
const uint8_t IN2A = 5;
const uint8_t IN2B = 7;

class PID {
public:
  PID(float kp, float ki, float kd, float upperLimit = 255)
      : kp_(kp), ki_(ki), kd_(kd), upperLimit_(upperLimit) { reset(); }

  void reset() {
    lastTime_  = millis();
    lastError_ = 0.0f;
    integral_  = 0.0f;
  }

  float calculate(float error) {
    unsigned long now = millis();
    float dt = max(1.0f, float(now - lastTime_)) / 1000.0f;

    float dErr  = (error - lastError_) / dt;
    integral_  += (error + lastError_) * 0.5f * dt;
    integral_   = constrain(integral_, -upperLimit_, upperLimit_);

    float out = kp_ * error + ki_ * integral_ + kd_ * dErr;
    lastError_ = error;
    lastTime_  = now;
    return constrain(out, -upperLimit_, upperLimit_);
  }

private:
  float kp_, ki_, kd_, upperLimit_;
  unsigned long lastTime_;
  float lastError_, integral_;
};

PID xPid(8, 0, 0.0001);
PID yPid(8, 0, 0.0001);


inline bool isValidDigit(char c) {
  return c >= '0' && c <= '9';
}

inline uint16_t digitsToInt(char d1, char d2, char d3) {
  return (d1 - '0') * 100 + (d2 - '0') * 10 + (d3 - '0');
}
inline void setPinDirs(bool a, bool b, uint8_t pinA, uint8_t pinB) {
  digitalWrite(pinA, a);
  digitalWrite(pinB, b);
}

void setup() {
  pinMode(EN1, OUTPUT);  pinMode(IN1A, OUTPUT);  pinMode(IN1B, OUTPUT);
  pinMode(EN2, OUTPUT);  pinMode(IN2A, OUTPUT);  pinMode(IN2B, OUTPUT);

  Serial.begin(115200);
  xPid.reset();  yPid.reset();
}

void loop() {
  if (Serial.available() < 8) {
    // No packet available - stop motors
    // analogWrite(EN1, 0);
    // analogWrite(EN2, 0);
    return;
  }

  char dirV = Serial.read();
  char v1   = Serial.read(); char v2 = Serial.read(); char v3 = Serial.read();
  char dirH = Serial.read();
  char h1   = Serial.read(); char h2 = Serial.read(); char h3 = Serial.read();

  // Validate packet format
  if ((dirV != 'U' && dirV != 'D' && dirV != 'N') ||
      (dirH != 'L' && dirH != 'R' && dirH != 'N') ||
      !isValidDigit(v1) || !isValidDigit(v2) || !isValidDigit(v3) ||
      !isValidDigit(h1) || !isValidDigit(h2) || !isValidDigit(h3)) {
    // Invalid packet - clear buffer and return
    while (Serial.available() > 0) Serial.read();
    return;
  }


  int16_t valV = digitsToInt(v1, v2, v3);
  int16_t valH = digitsToInt(h1, h2, h3);

  // Declare error variables
  int16_t errV, errH;

  // Special case: N000N000 packet acts like U100L000 (only when Python is running)
  if (dirV == 'N' && dirH == 'N') {
    errV = 100;  // Move up with PWM 100
    errH = 0;    // No horizontal movement
  } else {
    errV = ((dirV == 'D') ? -valV : valV);
    errH = ((dirH == 'L') ? -valH : valH);
  }

  int16_t dutyH = xPid.calculate(errH);
  int16_t dutyV = yPid.calculate(errV);

  setPinDirs(-dutyV >= 0, -dutyV < 0,  IN1A, IN1B);
  setPinDirs(dutyH >= 0, dutyH < 0,  IN2A, IN2B);

  analogWrite(EN1, constrain(abs(-dutyV), 0, 255));
  analogWrite(EN2, constrain(abs(dutyH), 0, 255));
}
