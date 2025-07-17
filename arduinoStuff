#define RED_PIN 9
#define GREEN_PIN 10
#define BLUE_PIN 11

void setup() {
  Serial.begin(9600);
  pinMode(RED_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
}

void loop() {
  if (Serial.available() > 0) {
    char command = Serial.read();

    switch (command) {
      case 'L': // Move Left -> Yellow
        setColor(255, 255, 0);
        break;
      case 'R': // Move Right -> Purple
        setColor(255, 0, 255);
        break;
      case 'U': // Move Up -> Blue
        setColor(0, 0, 255);
        break;
      case 'D': // Move Down -> Green
        setColor(0, 255, 0);
        break;
      case 'N': // No eye detected -> Red
        setColor(255, 0, 0);
        break;
      case 'C': // Centered -> White
        setColor(255, 255, 255);
        break;
      default:
        setColor(0, 0, 0); // Turn off LED
        break;
    }
  }
}

void setColor(int red, int green, int blue) {
  analogWrite(RED_PIN, red);
  analogWrite(GREEN_PIN, green);
  analogWrite(BLUE_PIN, blue);
}

