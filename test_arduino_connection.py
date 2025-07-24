#!/usr/bin/env python3
"""
Quick test to check if Arduino WiFi server is accessible
"""
import requests
import socket

ARDUINO_IP = "192.168.1.60"
ARDUINO_PORT = 8080

def test_arduino_connection():
    print(f"Testing Arduino connection at {ARDUINO_IP}:{ARDUINO_PORT}")
    print("=" * 50)
    
    # Test 1: Ping test (basic connectivity)
    print("1. Testing basic connectivity...")
    try:
        import subprocess
        result = subprocess.run(['ping', '-c', '1', ARDUINO_IP], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print("✓ Arduino IP is reachable via ping")
        else:
            print("❌ Arduino IP is NOT reachable via ping")
            print("   Make sure Arduino is powered on and connected to WiFi")
            return
    except Exception as e:
        print(f"⚠️ Ping test failed: {e}")
    
    # Test 2: Port connectivity test
    print("\n2. Testing port connectivity...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((ARDUINO_IP, ARDUINO_PORT))
        sock.close()
        
        if result == 0:
            print(f"✓ Port {ARDUINO_PORT} is open and accepting connections")
        else:
            print(f"❌ Port {ARDUINO_PORT} is closed or not responding")
            print("   Make sure PlotterMovementPIDWifi.ino is uploaded and running")
            return
    except Exception as e:
        print(f"⚠️ Port test failed: {e}")
        return
    
    # Test 3: HTTP request test
    print("\n3. Testing HTTP server...")
    try:
        response = requests.get(f"http://{ARDUINO_IP}:{ARDUINO_PORT}/status", timeout=5)
        if response.status_code == 200:
            print("✓ Arduino HTTP server is responding!")
            print(f"Response: {response.text}")
        else:
            print(f"⚠️ HTTP server responded with status {response.status_code}")
    except requests.exceptions.ConnectTimeout:
        print("❌ HTTP connection timed out")
        print("   Arduino may be running but HTTP server not responding")
    except requests.exceptions.ConnectionError:
        print("❌ HTTP connection failed")
        print("   Check if PlotterMovementPIDWifi.ino is properly uploaded")
    except Exception as e:
        print(f"❌ HTTP test failed: {e}")
    
    print("\n" + "=" * 50)
    print("Next steps:")
    print("1. Upload PlotterMovementPIDWifi.ino to Arduino R4 WiFi")
    print("2. Open Serial Monitor (115200 baud) to check WiFi connection")
    print("3. Ensure Arduino and computer are on same WiFi network")

if __name__ == "__main__":
    test_arduino_connection()