#include <Arduino.h>
#include <WiFi.h>

// WiFi credentials - update these for your network
const char* ssid = "ket_iot_net";
const char* password = "ket_iot19104";

// WiFi server on port 8080
WiFiServer server(8080);

// Global plotter state - default OFF, controlled by phone
bool plotterEnabled = false;
bool wifiConnected = false;

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

void initializeWiFi() {
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(100);
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    server.begin();
  } else {
    wifiConnected = false;
  }
}

void handleWiFiCommands() {
  if (!wifiConnected) return;
  
  WiFiClient client = server.available();
  if (!client) return;
  
  String request = "";
  unsigned long startTime = millis();
  
  // Read the request with timeout
  while (client.connected() && (millis() - startTime < 1000)) {
    if (client.available()) {
      char c = client.read();
      request += c;
      if (request.endsWith("\r\n\r\n") || request.endsWith("\n\n")) {
        break;
      }
    }
  }
  
  // Parse HTTP request
  String response = "";
  String contentType = "application/json";
  
  if (request.indexOf("GET /start") >= 0) {
    plotterEnabled = true;
    xPid.reset();  
    yPid.reset();
    response = "{\"status\":\"started\",\"enabled\":" + String(plotterEnabled ? "true" : "false") + "}";
    
  } else if (request.indexOf("GET /stop") >= 0) {
    plotterEnabled = false;
    // Stop motors immediately
    analogWrite(EN1, 0);
    analogWrite(EN2, 0);
    response = "{\"status\":\"stopped\",\"enabled\":" + String(plotterEnabled ? "true" : "false") + "}";
    
  } else if (request.indexOf("GET /status") >= 0) {
    response = "{\"status\":\"" + String(plotterEnabled ? "enabled" : "disabled") + "\",\"enabled\":" + 
               String(plotterEnabled ? "true" : "false") + ",\"wifi\":true}";
               
  } else {
    response = "{\"error\":\"Unknown command\"}";
  }
  
  // Send HTTP response
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: " + contentType);
  client.println("Access-Control-Allow-Origin: *");
  client.println("Connection: close");
  client.println();
  client.println(response);
  client.flush();
  
  // Allow more time for client to read response before closing
  delay(50);
  client.stop();
}

void setup() {
  pinMode(EN1, OUTPUT);  pinMode(IN1A, OUTPUT);  pinMode(IN1B, OUTPUT);
  pinMode(EN2, OUTPUT);  pinMode(IN2A, OUTPUT);  pinMode(IN2B, OUTPUT);

  Serial.begin(115200);
  
  xPid.reset();  
  yPid.reset();
  
  // Initialize WiFi
  initializeWiFi();
}

void loop() {
  // Handle WiFi commands first
  handleWiFiCommands();
  
  // If plotter is not enabled, stop motors and return
  if (!plotterEnabled) {
    analogWrite(EN1, 0);
    analogWrite(EN2, 0);
    
    // Still need to clear serial buffer to prevent overflow
    while (Serial.available() > 0) {
      Serial.read();
    }
    return;
  }
  
  // Plotter is enabled - process serial commands as before
  if (Serial.available() < 8) {
    // No packet available - but don't stop motors, just return
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
