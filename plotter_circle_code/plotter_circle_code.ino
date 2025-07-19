#include <math.h>

#define EN1 9
#define A1_1 12
#define A1_2 13

#define EN2 3
#define A2_1 5
#define A2_2 7

bool xIncreasing = 1;
bool yIncreasing = 1;
int xSpeedModifier = -3;
int xSpeed = 255;

void setup() {
  pinMode(EN1, OUTPUT);
  pinMode(A1_1, OUTPUT);
  pinMode(A1_2, OUTPUT);

  pinMode(EN2, OUTPUT);
  pinMode(A2_1, OUTPUT);
  pinMode(A2_2, OUTPUT);

  analogWrite(EN1, 255);
  analogWrite(EN2, 255);

  digitalWrite(A1_2, 1);
  digitalWrite(A2_2, 1);

  delay(8000);

  analogWrite(EN1, 0);
  analogWrite(EN2, 0);

  digitalWrite(A1_2, 0);
  digitalWrite(A2_2, 0);

  delay(500);

  analogWrite(EN1, 255);
  analogWrite(EN2, 255);

  digitalWrite(A1_1, 1);
  digitalWrite(A2_1, 1);

  // delay(1000);
  // digitalWrite(A2_1, 0);
  // analogWrite(EN2, 0);

  delay(3000);
  digitalWrite(A1_1, 0);
  analogWrite(EN1, 0);

  Serial.begin(9600);

}

void loop() {
  int ySpeed = (int) round(sqrt(pow(255,2) - pow(xSpeed, 2)));

  analogWrite(EN1, xSpeed);
  analogWrite(EN2, ySpeed);

  digitalWrite((xIncreasing) ? A1_1 : A1_2, 1);
  digitalWrite((xIncreasing) ? A1_2 : A1_1, 0);

  digitalWrite((yIncreasing) ? A2_1 : A2_2, 1);
  digitalWrite((yIncreasing) ? A2_2 : A2_1, 0);

  xSpeed += xSpeedModifier;
  
  if (xSpeed <= 80) {
    xSpeed = 80 ;
    xSpeedModifier = 3;
    xIncreasing = !xIncreasing;
  } else if (xSpeed >= 242) {
    xSpeed = 242;
    xSpeedModifier = -3;
    yIncreasing = !yIncreasing;
  }

  Serial.print("xSpeed: ");
  Serial.print((xIncreasing) ? xSpeed : -xSpeed);
  Serial.print(" ySpeed: ");
  Serial.println((yIncreasing) ? ySpeed : -ySpeed);
}
