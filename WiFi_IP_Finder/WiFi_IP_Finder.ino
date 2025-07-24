#include <WiFi.h>

// WiFi credentials - update these for your network
const char* ssid = "ket_iot_net";
const char* password = "ket_iot19104";

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=== Arduino R4 WiFi IP Finder ===");
  Serial.print("Connecting to: ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ WiFi Connected Successfully!");
    Serial.println("==============================");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Gateway: ");
    Serial.println(WiFi.gatewayIP());
    Serial.print("Subnet: ");
    Serial.println(WiFi.subnetMask());
    Serial.print("DNS: ");
    Serial.println(WiFi.dnsIP());
    Serial.println("==============================");
    Serial.println();
    Serial.println("Copy this IP address to:");
    Serial.println("DeviceService.swift -> arduinoHost");
    Serial.println();
    Serial.print("Test in browser: http://");
    Serial.print(WiFi.localIP());
    Serial.println(":8080/status");
  } else {
    Serial.println("❌ WiFi Connection Failed!");
    Serial.println("Check your credentials and try again.");
  }
}

void loop() {
  // Keep WiFi alive and show status every 10 seconds
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Status: Connected | IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Status: Disconnected - Attempting reconnect...");
    WiFi.begin(ssid, password);
  }
  
  delay(10000);
}