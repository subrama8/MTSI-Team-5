import cv2

def test_cameras():
    print("Testing all available cameras...")
    
    for i in range(3):
        print(f"\nTrying camera index {i}:")
        cap = cv2.VideoCapture(i)
        
        if not cap.isOpened():
            print(f"  Index {i}: Not available")
            continue
            
        # Get camera info
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        
        ret, frame = cap.read()
        if ret:
            print(f"  Index {i}: {width}x{height} @ {fps}fps - WORKING")
            cv2.imshow(f'Camera Index {i}', frame)
            cv2.waitKey(2000)  # Show for 2 seconds
            cv2.destroyAllWindows()
        else:
            print(f"  Index {i}: Cannot read frame")
            
        cap.release()
    
    print("\nWhich camera index would you like to use? (0, 1, or 2)")

if __name__ == "__main__":
    test_cameras()