import cv2

def list_cameras():
    """List all available cameras and their ports."""
    print("Scanning for available cameras...")
    available_cameras = []
    
    # Test ports 0-10 (usually sufficient for most systems)
    for port in range(11):
        cap = cv2.VideoCapture(port)
        if cap.isOpened():
            # Try to read a frame to verify the camera is working
            ret, frame = cap.read()
            if ret:
                # Get camera properties
                width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                fps = cap.get(cv2.CAP_PROP_FPS)
                
                available_cameras.append({
                    'port': port,
                    'width': width,
                    'height': height,
                    'fps': fps
                })
                
                print(f"Port {port}: Camera found - {width}x{height} @ {fps:.1f} FPS")
            cap.release()
        else:
            cap.release()
    
    if not available_cameras:
        print("No cameras found on any port.")
    else:
        print(f"\nFound {len(available_cameras)} camera(s) total.")
    
    return available_cameras

if __name__ == "__main__":
    cameras = list_cameras()