#!/usr/bin/env python3
"""
Simple HTTP test for Arduino WiFi server
"""
import requests
import time

ARDUINO_IP = "192.168.1.60"
ARDUINO_PORT = 8080

def test_simple_request():
    """Test a simple HTTP request to Arduino"""
    try:
        print(f"Sending GET request to http://{ARDUINO_IP}:{ARDUINO_PORT}/status")
        
        # Try with a longer timeout and detailed error handling
        response = requests.get(
            f"http://{ARDUINO_IP}:{ARDUINO_PORT}/status", 
            timeout=10,
            headers={'User-Agent': 'Python-Test'}
        )
        
        print(f"✓ Response received!")
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        print(f"Content: {response.text}")
        
        return True
        
    except requests.exceptions.ConnectTimeout:
        print("❌ Connection timed out - Arduino server may not be responding")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"❌ Connection error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_raw_socket():
    """Test raw socket connection"""
    import socket
    
    try:
        print(f"\nTrying raw socket connection to {ARDUINO_IP}:{ARDUINO_PORT}")
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((ARDUINO_IP, ARDUINO_PORT))
        
        # Send HTTP request
        request = f"GET /status HTTP/1.1\r\nHost: {ARDUINO_IP}\r\nConnection: close\r\n\r\n"
        sock.send(request.encode())
        
        # Receive response
        response = sock.recv(1024).decode()
        sock.close()
        
        print("✓ Raw socket connection successful!")
        print(f"Response:\n{response}")
        return True
        
    except Exception as e:
        print(f"❌ Raw socket failed: {e}")
        return False

if __name__ == "__main__":
    print("Arduino WiFi Server Test")
    print("=" * 30)
    
    # Test 1: HTTP request
    print("1. Testing HTTP request...")
    test_simple_request()
    
    # Test 2: Raw socket
    print("\n2. Testing raw socket...")
    test_raw_socket()
    
    print(f"\n💡 Make sure PlotterMovementPIDWifi.ino is uploaded to Arduino")
    print(f"💡 Check Arduino Serial Monitor (115200 baud) for WiFi connection status")