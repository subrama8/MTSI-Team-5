#include <Arduino.h>
#include <WiFiS3.h>
#include <ArduinoJson.h>

// WiFi credentials - these should be configured via serial setup command
char ssid[] = "";        // Will be set via setup
char pass[] = "";        // Will be set via setup
WiFiServer server(80);
WiFiClient currentClient;
bool wifiConfigured = false;
bool plotterEnabled = false;
String deviceName = "EyeTracker_Plotter";

// Motor control pins (same as original)
const uint8_t EN1  = 9;
const uint8_t IN1A = 12;
const uint8_t IN1B = 13;
const uint8_t EN2  = 3;
const uint8_t IN2A = 5;
const uint8_t IN2B = 7;

// PID Controller class (unchanged)
class PID {
public:
  PID(float kp, float ki, float kd, float upperLimit = 255)
      : kp_(kp), ki_(ki), kd_(kd), upperLimit(upperLimit) { reset(); }

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
    integral_   = constrain(integral_, -upperLimit, upperLimit);

    float out = kp_ * error + ki_ * integral_ + kd_ * dErr;
    lastError_ = error;
    lastTime_  = now;
    return constrain(out, -upperLimit, upperLimit);
  }

private:
  float kp_, ki_, kd_, upperLimit_;
  unsigned long lastTime_;
  float lastError_, integral_;
};

PID xPid(0.001, 0, 0.0001);
PID yPid(0.001, 0, 0.0001);

// Helper functions (unchanged)
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

void processEyePacket(String packet) {
  if (packet.length() != 8) return;
  
  char dirV = packet[0];
  char v1 = packet[1], v2 = packet[2], v3 = packet[3];
  char dirH = packet[4];
  char h1 = packet[5], h2 = packet[6], h3 = packet[7];

  // Validate packet format (same validation as serial version)
  if ((dirV != 'U' && dirV != 'D' && dirV != 'N') ||
      (dirH != 'L' && dirH != 'R' && dirH != 'N') ||
      !isValidDigit(v1) || !isValidDigit(v2) || !isValidDigit(v3) ||
      !isValidDigit(h1) || !isValidDigit(h2) || !isValidDigit(h3)) {
    return;
  }

  // Only process if plotter is enabled
  if (!plotterEnabled) {
    // Stop motors when disabled
    analogWrite(EN1, 0);
    analogWrite(EN2, 0);
    return;
  }

  int16_t valV = digitsToInt(v1, v2, v3);
  int16_t valH = digitsToInt(h1, h2, h3);

  int16_t errV = (dirV == 'N') ? 0 : ((dirV == 'D') ? -valV : valV);
  int16_t errH = (dirH == 'N') ? 0 : ((dirH == 'L') ? -valH : valH);

  // Reset PID controllers if no eye detected to prevent integral windup
  if (dirV == 'N' && dirH == 'N') {
    xPid.reset();
    yPid.reset();
  }

  int16_t dutyH = xPid.calculate(errH);
  int16_t dutyV = yPid.calculate(errV);

  setPinDirs(dutyH >= 0, dutyH < 0, IN1A, IN1B);
  setPinDirs(dutyV >= 0, dutyV < 0, IN2A, IN2B);

  analogWrite(EN1, constrain(abs(dutyH), 0, 255));
  analogWrite(EN2, constrain(abs(dutyV), 0, 255));
}

void handleWiFiClient() {
  WiFiClient client = server.available();
  if (!client) return;

  String request = "";
  while (client.connected() && client.available()) {
    char c = client.read();
    request += c;
    
    // Process complete HTTP requests
    if (request.endsWith("\r\n\r\n")) {
      break;
    }
  }

  // CORS headers for web app compatibility
  String corsHeaders = "Access-Control-Allow-Origin: *\r\n";
  corsHeaders += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
  corsHeaders += "Access-Control-Allow-Headers: Content-Type\r\n";

  // Handle OPTIONS (preflight) requests
  if (request.startsWith("OPTIONS")) {
    client.println("HTTP/1.1 204 No Content");
    client.println(corsHeaders);
    client.println();
    client.stop();
    return;
  }

  // API Endpoints
  if (request.indexOf("GET /api/status") >= 0) {
    // Return device status
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println(corsHeaders);
    client.println();
    
    StaticJsonDocument<200> status;
    status["device"] = deviceName;
    status["plotterEnabled"] = plotterEnabled;
    status["wifiConnected"] = WiFi.status() == WL_CONNECTED;
    status["ipAddress"] = WiFi.localIP().toString();
    
    String response;
    serializeJson(status, response);
    client.println(response);
  }
  else if (request.indexOf("POST /api/plotter/start") >= 0) {
    // Start plotter
    plotterEnabled = true;
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println(corsHeaders);
    client.println();
    client.println("{\"status\":\"started\",\"plotterEnabled\":true}");
  }
  else if (request.indexOf("POST /api/plotter/stop") >= 0) {
    // Stop plotter
    plotterEnabled = false;
    // Immediately stop motors
    analogWrite(EN1, 0);
    analogWrite(EN2, 0);
    xPid.reset();
    yPid.reset();
    
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println(corsHeaders);
    client.println();
    client.println("{\"status\":\"stopped\",\"plotterEnabled\":false}");
  }
  else if (request.indexOf("POST /api/eye-data") >= 0) {
    // Process eye tracking data
    int bodyStart = request.indexOf("\r\n\r\n");
    if (bodyStart >= 0) {
      String body = request.substring(bodyStart + 4);
      
      StaticJsonDocument<100> doc;
      DeserializationError error = deserializeJson(doc, body);
      
      if (!error && doc.containsKey("packet")) {
        String packet = doc["packet"];
        processEyePacket(packet);
        
        client.println("HTTP/1.1 200 OK");
        client.println("Content-Type: application/json");
        client.println(corsHeaders);
        client.println();
        client.println("{\"status\":\"processed\"}");
      } else {
        client.println("HTTP/1.1 400 Bad Request");
        client.println(corsHeaders);
        client.println();
        client.println("{\"error\":\"Invalid packet data\"}");
      }
    }
  }
  else if (request.indexOf("GET /api/discover") >= 0) {
    // Device discovery endpoint
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println(corsHeaders);
    client.println();
    
    StaticJsonDocument<150> discovery;
    discovery["device"] = deviceName;
    discovery["type"] = "eye-tracker-plotter";
    discovery["version"] = "1.0";
    discovery["capabilities"] = "plotter,eye-tracking";
    
    String response;
    serializeJson(discovery, response);
    client.println(response);
  }
  else {
    // 404 Not Found
    client.println("HTTP/1.1 404 Not Found");
    client.println(corsHeaders);
    client.println();
    client.println("{\"error\":\"Endpoint not found\"}");
  }

  client.stop();
}

void handleSerialSetup() {
  if (!Serial.available()) return;
  
  String command = Serial.readStringUntil('\n');
  command.trim();
  
  if (command.startsWith("WIFI_CONFIG:")) {
    // Format: WIFI_CONFIG:SSID,PASSWORD
    int commaPos = command.indexOf(',', 12);
    if (commaPos > 12) {
      String newSSID = command.substring(12, commaPos);
      String newPass = command.substring(commaPos + 1);
      
      newSSID.toCharArray(ssid, sizeof(ssid));
      newPass.toCharArray(pass, sizeof(pass));
      
      Serial.println("WiFi config updated. Attempting connection...");
      
      // Attempt WiFi connection
      WiFi.begin(ssid, pass);
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
      }
      
      if (WiFi.status() == WL_CONNECTED) {
        wifiConfigured = true;
        Serial.println();
        Serial.print("WiFi connected! IP: ");
        Serial.println(WiFi.localIP());
        server.begin();
      } else {
        Serial.println();
        Serial.println("WiFi connection failed.");
      }
    }
  }
  else if (command == "STATUS") {
    Serial.print("Device: ");
    Serial.println(deviceName);
    Serial.print("WiFi Status: ");
    Serial.println(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
    }
    Serial.print("Plotter Enabled: ");
    Serial.println(plotterEnabled ? "Yes" : "No");
  }
}

void handleSerialPackets() {
  // Maintain backward compatibility with serial communication
  if (Serial.available() >= 8) {
    char buffer[9];
    Serial.readBytes(buffer, 8);
    buffer[8] = '\0';
    
    processEyePacket(String(buffer));
  }
}

void setup() {
  // Initialize motor control pins
  pinMode(EN1, OUTPUT);  pinMode(IN1A, OUTPUT);  pinMode(IN1B, OUTPUT);
  pinMode(EN2, OUTPUT);  pinMode(IN2A, OUTPUT);  pinMode(IN2B, OUTPUT);

  Serial.begin(115200);
  xPid.reset();  yPid.reset();
  
  Serial.println("Eye Tracker Plotter - WiFi Enabled");
  Serial.println("Commands:");
  Serial.println("  WIFI_CONFIG:SSID,PASSWORD - Configure WiFi");
  Serial.println("  STATUS - Show current status");
  Serial.println("Or send 8-byte eye tracking packets directly");
}

void loop() {
  // Handle serial configuration commands
  handleSerialSetup();
  
  // Handle serial eye tracking packets (backward compatibility)
  handleSerialPackets();
  
  // Handle WiFi clients if connected
  if (wifiConfigured && WiFi.status() == WL_CONNECTED) {
    handleWiFiClient();
  }
  
  delay(1); // Small delay to prevent overwhelming the loop
}