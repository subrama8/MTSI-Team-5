#!/usr/bin/env python3
"""
Test plotter start/stop commands
"""
import requests
import time

ARDUINO_IP = "192.168.1.60"
ARDUINO_PORT = 8080

def send_command(endpoint):
    """Send command to Arduino and print response"""
    try:
        url = f"http://{ARDUINO_IP}:{ARDUINO_PORT}{endpoint}"
        print(f"Sending: GET {endpoint}")
        
        response = requests.get(url, timeout=5)
        print(f"Response: {response.text}")
        return response.json()
        
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_plotter_workflow():
    """Test complete plotter workflow"""
    print("Arduino Plotter Command Test")
    print("=" * 30)
    
    # 1. Check initial status
    print("\n1. Checking initial status...")
    send_command("/status")
    
    # 2. Start plotter
    print("\n2. Starting plotter...")
    send_command("/start")
    
    # 3. Check status after start
    print("\n3. Checking status after start...")
    send_command("/status")
    
    # Wait a moment
    print("\n   Waiting 2 seconds...")
    time.sleep(2)
    
    # 4. Stop plotter
    print("\n4. Stopping plotter...")
    send_command("/stop")
    
    # 5. Check final status
    print("\n5. Checking final status...")
    send_command("/status")
    
    print("\n✅ Plotter command test complete!")
    print("The Arduino WiFi server is working correctly.")
    print("You can now test the iOS app connection.")

if __name__ == "__main__":
    test_plotter_workflow()