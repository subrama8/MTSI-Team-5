import React, { useRef, useEffect, useState } from 'react';

interface FaceMeshProcessorProps {
  imageFile: File | null;
  onResult: (result: any) => void;
  onError: (error: string) => void;
}

export const FaceMeshProcessor: React.FC<FaceMeshProcessorProps> = ({
  imageFile,
  onResult,
  onError,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [faceMesh, setFaceMesh] = useState<any>(null);
  const [isInitializing, setIsInitializing] = useState(false);

  useEffect(() => {
    const initializeFaceMesh = async () => {
      if (isInitializing) return;
      setIsInitializing(true);
      
      try {
        console.log('Starting MediaPipe initialization...');
        
        // Load MediaPipe from CDN in production, use local in development
        let FaceMesh;
        
        if (import.meta.env.PROD) {
          // In production, load from CDN
          if (!window.FaceMesh) {
            // Load the script if not already loaded
            await new Promise((resolve, reject) => {
              const script = document.createElement('script');
              script.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4.1633559619/face_mesh.js';
              script.onload = resolve;
              script.onerror = reject;
              document.head.appendChild(script);
            });
          }
          FaceMesh = window.FaceMesh;
        } else {
          // In development, use the npm package
          const module = await import('@mediapipe/face_mesh');
          FaceMesh = module.FaceMesh;
        }
        
        console.log('MediaPipe module loaded, creating FaceMesh instance...');
        
        const mesh = new FaceMesh({
          locateFile: (file) => {
            console.log('Locating file:', file);
            return `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4.1633559619/${file}`;
          }
        });

        console.log('Setting MediaPipe options...');
        
        // Set options
        mesh.setOptions({
          maxNumFaces: 10,
          refineLandmarks: true,
          minDetectionConfidence: 0.3,
          minTrackingConfidence: 0.3
        });

        console.log('Setting up results handler...');
        
        // Set up results handler
        mesh.onResults((results) => {
          console.log('MediaPipe results received:', results);
          onResult(results);
        });

        console.log('MediaPipe initialized successfully');
        setFaceMesh(mesh);
        setIsInitializing(false);
        
      } catch (error) {
        console.error('Failed to initialize Face Mesh:', error);
        setIsInitializing(false);
        onError(`Failed to initialize face detection. ${error.message}. Please try refreshing the page or using a different browser.`);
      }
    };

    initializeFaceMesh();

    return () => {
      if (faceMesh) {
        try {
          faceMesh.close();
        } catch (error) {
          console.warn('Error closing MediaPipe:', error);
        }
      }
      setIsInitializing(false);
    };
  }, []); // Remove onResult and onError from dependencies to prevent re-initialization

  useEffect(() => {
    if (!faceMesh || !imageFile || isInitializing) return;

    const processImage = async () => {
      try {
        console.log('Processing image with MediaPipe...');
        const img = new Image();
        img.crossOrigin = 'anonymous';
        
        img.onload = async () => {
          try {
            const canvas = canvasRef.current;
            if (!canvas) {
              throw new Error('Canvas not available');
            }
            
            const ctx = canvas.getContext('2d');
            if (!ctx) {
              throw new Error('Canvas context not available');
            }
            
            canvas.width = img.width;
            canvas.height = img.height;
            ctx.drawImage(img, 0, 0);
            
            console.log('Sending image to MediaPipe for processing...');
            await faceMesh.send({ image: canvas });
            
          } catch (error) {
            console.error('Error sending image to face mesh:', error);
            onError(`Failed to process image: ${error.message}. Please try with a different image.`);
          }
        };
        
        img.onerror = () => {
          console.error('Failed to load image');
          onError('Failed to load the selected image. Please try a different file format (JPG, PNG, WebP).');
        };

        const reader = new FileReader();
        reader.onload = (e) => {
          console.log('Image file read successfully, loading into canvas...');
          img.src = e.target?.result as string;
        };
        
        reader.onerror = () => {
          console.error('Failed to read file');
          onError('Failed to read the image file. Please try a different file.');
        };
        
        reader.readAsDataURL(imageFile);
        
      } catch (error) {
        console.error('Error processing image:', error);
        onError(`Error processing image: ${error.message}. Please try again.`);
      }
    };

    processImage();
  }, [faceMesh, imageFile, isInitializing]);

  // Processing timeout
  useEffect(() => {
    if (!imageFile || !faceMesh || isInitializing) return;

    // Only set timeout if we haven't received results yet
    let timeoutId: NodeJS.Timeout;
    let hasReceivedResults = false;
    
    const originalOnResult = onResult;
    const wrappedOnResult = (results: any) => {
      hasReceivedResults = true;
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      originalOnResult(results);
    };
    
    // Set a longer timeout and only if no results received
    timeoutId = setTimeout(() => {
      if (!hasReceivedResults) {
        console.warn('Face detection is taking longer than expected');
        onError('Face detection is taking longer than expected. The image might be too large or complex. Please try with a smaller or clearer image.');
      }
    }, 45000);

    return () => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
  }, [imageFile, faceMesh, isInitializing]);

  return (
    <canvas
      ref={canvasRef}
      style={{ display: 'none' }}
    />
  );
};