#include <math.h>

#define EN1 9
#define A1_1 12
#define A1_2 13

#define EN2 3
#define A2_1 5
#define A2_2 7

int xSpeed = 0;
int ySpeed = 0;

void setup() {
  Serial.begin(9600);

  pinMode(EN1, OUTPUT);
  pinMode(A1_1, OUTPUT);
  pinMode(A1_2, OUTPUT);

  pinMode(EN2, OUTPUT);
  pinMode(A2_1, OUTPUT);
  pinMode(A2_2, OUTPUT);
}

void setMotor(int enPin, int dirPin1, int dirPin2, int speedVal) {
  speedVal = constrain(speedVal, -255, 255);
  analogWrite(enPin, abs(speedVal));
  digitalWrite(dirPin1, speedVal > 0 ? HIGH : LOW);
  digitalWrite(dirPin2, speedVal < 0 ? HIGH : LOW);
}

void loop() {
  static String input = "";

  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n') {
      parseCommand(input);
      input = "";
    } else {
      input += ch;
    }
  }

  setMotor(EN1, A1_1, A1_2, xSpeed);
  setMotor(EN2, A2_1, A2_2, ySpeed);
}

void parseCommand(String cmd) {
  if (!cmd.startsWith("MOVE")) return;

  int xIndex = cmd.indexOf('X');
  int yIndex = cmd.indexOf('Y');

  int dx = cmd.substring(xIndex + 1, yIndex).toInt();
  int dy = cmd.substring(yIndex + 1).toInt();

  // Scale to PWM values
  xSpeed = constrain(dx * 15, -255, 255);
  ySpeed = constrain(dy * 15, -255, 255);
}
