/*  PWM eye‑tracker indicator – v3
    ─────────────────────────────────
    Host packet: 8 ASCII bytes, e.g.  "D100R050", "U000L200", "N000N000"

        [0]  dirV  : 'U', 'D', or 'N'        (vertical  direction)
        [1‑3] valV : 000‑255                 (vertical  magnitude)
        [4]  dirH  : 'R', 'L', or 'N'        (horizontal direction)
        [5‑7] valH : 000‑255                 (horizontal magnitude)

    Behaviour:
      • U/D modulate TOP or BOTTOM LED, respectively.
      • R/L modulate RIGHT or LEFT  LED, respectively.
      • On "N000N000" (no eye detected) **all four LEDs drive to 255**.

    Pin map (unchanged):
        top    → 11   (PWM)
        bottom → 5    (PWM)
        right  → 10   (PWM)
        left   → 6    (PWM)
*/

const uint8_t LED_TOP    = 11;
const uint8_t LED_LEFT   = 6;
const uint8_t LED_BOTTOM = 5;
const uint8_t LED_RIGHT  = 10;

const uint8_t LED_CENTER = 2;

void setup() {
  Serial.begin(9600);

  pinMode(LED_TOP,    OUTPUT);
  pinMode(LED_BOTTOM, OUTPUT);
  pinMode(LED_RIGHT,  OUTPUT);
  pinMode(LED_LEFT,   OUTPUT);
  pinMode(LED_CENTER,   OUTPUT);

  analogWrite(LED_TOP,    0);
  analogWrite(LED_BOTTOM, 0);
  analogWrite(LED_RIGHT,  0);
  analogWrite(LED_LEFT,   0);
  analogWrite(LED_CENTER,   0);
}

/* Convert three ASCII digits to 0‑255 */
inline uint8_t digitsToInt(char d1, char d2, char d3) {
  return (d1 - '0') * 100 + (d2 - '0') * 10 + (d3 - '0');
}

void loop() {
  if (Serial.available() >= 8) {

    char dirV = Serial.read();          // 'U', 'D', or 'N'
    char v1   = Serial.read();
    char v2   = Serial.read();
    char v3   = Serial.read();

    char dirH = Serial.read();          // 'R', 'L', or 'N'
    char h1   = Serial.read();
    char h2   = Serial.read();
    char h3   = Serial.read();

    /* discard CR/LF if present */
    while (Serial.peek() == '\n' || Serial.peek() == '\r') Serial.read();

    uint8_t valV = constrain(digitsToInt(v1, v2, v3), 0, 255);
    uint8_t valH = constrain(digitsToInt(h1, h2, h3), 0, 255);

    /* -------- Handle "no eye" packet ---------------------------------- */
    if (dirV == 'N' && dirH == 'N') {
      analogWrite(LED_TOP,    255);
      analogWrite(LED_BOTTOM, 255);
      analogWrite(LED_RIGHT,  255);
      analogWrite(LED_LEFT,   255);
      return;                           // skip rest of processing
    }

    if (abs(valV)<=10 && abs(valH) <=10) {
      digitalWrite(LED_CENTER, 1);
    } else {
      digitalWrite(LED_CENTER, 0);
    }

    /* -------- vertical axis ------------------------------------------- */
    if (dirV == 'U') {                  // Up → TOP
      analogWrite(LED_TOP,    valV);
      analogWrite(LED_BOTTOM, 0);
    } else if (dirV == 'D') {           // Down → BOTTOM
      analogWrite(LED_BOTTOM, valV);
      analogWrite(LED_TOP,    0);
    } else {                            // unexpected char
      analogWrite(LED_TOP,    0);
      analogWrite(LED_BOTTOM, 0);
    }

    /* -------- horizontal axis ----------------------------------------- */
    if (dirH == 'R') {                  // Right → RIGHT
      analogWrite(LED_RIGHT, valH);
      analogWrite(LED_LEFT,  0);
    } else if (dirH == 'L') {           // Left  → LEFT
      analogWrite(LED_LEFT,  valH);
      analogWrite(LED_RIGHT, 0);
    } else {                            // unexpected char
      analogWrite(LED_LEFT,  0);
      analogWrite(LED_RIGHT, 0);
    }
  }
}
