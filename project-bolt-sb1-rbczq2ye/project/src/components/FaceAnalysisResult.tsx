import React, { useRef, useEffect, useState } from 'react';
import { Eye, Download, RotateCcw, AlertCircle } from 'lucide-react';

interface EyeCenter {
  x: number;
  y: number;
  type: 'left' | 'right';
}

interface FaceAnalysisResultProps {
  imageFile: File;
  faceMeshResults: any;
  onReset: () => void;
}

export const FaceAnalysisResult: React.FC<FaceAnalysisResultProps> = ({
  imageFile,
  faceMeshResults,
  onReset,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [imageDataUrl, setImageDataUrl] = useState<string>('');
  const [eyeCenters, setEyeCenters] = useState<EyeCenter[]>([]);
  const [imageLoaded, setImageLoaded] = useState(false);
  const [imageError, setImageError] = useState(false);

  useEffect(() => {
    // Convert file to data URL for more reliable loading
    const reader = new FileReader();
    reader.onload = (e) => {
      if (e.target?.result) {
        setImageDataUrl(e.target.result as string);
      }
    };
    reader.onerror = () => {
      setImageError(true);
    };
    reader.readAsDataURL(imageFile);
    setImageLoaded(false);
    setImageError(false);
    
    // Cleanup function
    return () => {
      reader.abort();
    };
  }, [imageFile]);

  useEffect(() => {
    if (!faceMeshResults || !faceMeshResults.multiFaceLandmarks || !canvasRef.current || !imageDataUrl) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const img = new Image();
    
    let retryCount = 0;
    const maxRetries = 3;
    
    const loadImage = () => {
      const loadTimeout = setTimeout(() => {
        console.error('Image loading timeout, attempt:', retryCount + 1);
        if (retryCount < maxRetries) {
          retryCount++;
          setTimeout(loadImage, 1000);
        } else {
          setImageError(true);
          setImageLoaded(false);
        }
      }, 15000);
      
      img.onload = () => {
        clearTimeout(loadTimeout);
        try {
          canvas.width = img.width;
          canvas.height = img.height;
          
          // Clear canvas first
          ctx.clearRect(0, 0, canvas.width, canvas.height);
          
          // Draw the original image
          ctx.drawImage(img, 0, 0);
          setImageLoaded(true);
          setImageError(false);
          
          const detectedEyeCenters: EyeCenter[] = [];

          // Process each detected face
          faceMeshResults.multiFaceLandmarks.forEach((landmarks: any[]) => {
            // Left eye - using precise inner eye landmarks for pupil center calculation
            const leftEyeInnerLandmarks = [
              landmarks[468], landmarks[469], landmarks[470], landmarks[471], landmarks[472]  // Inner iris landmarks
            ];
            const leftEyeCornerLandmarks = [
              landmarks[33],   // outer corner
              landmarks[133],  // inner corner
              landmarks[159],  // top center
              landmarks[145]   // bottom center
            ];

            // Right eye - using precise inner eye landmarks for pupil center calculation  
            const rightEyeInnerLandmarks = [
              landmarks[473], landmarks[474], landmarks[475], landmarks[476], landmarks[477]  // Inner iris landmarks
            ];
            const rightEyeCornerLandmarks = [
              landmarks[362],  // outer corner
              landmarks[263],  // inner corner
              landmarks[386],  // top center
              landmarks[374]   // bottom center
            ];

            // Calculate center of left eye
            const leftEyeCenter = calculatePreciseEyeCenter(
              leftEyeInnerLandmarks, 
              leftEyeCornerLandmarks, 
              canvas.width, 
              canvas.height
            );
            if (leftEyeCenter) {
              detectedEyeCenters.push({ ...leftEyeCenter, type: 'left' });
            }

            // Calculate center of right eye
            const rightEyeCenter = calculatePreciseEyeCenter(
              rightEyeInnerLandmarks, 
              rightEyeCornerLandmarks, 
              canvas.width, 
              canvas.height
            );
            if (rightEyeCenter) {
              detectedEyeCenters.push({ ...rightEyeCenter, type: 'right' });
            }

            // Draw eye centers
            detectedEyeCenters.forEach((eyeCenter) => {
              // Draw outer circle
              ctx.beginPath();
              ctx.arc(eyeCenter.x, eyeCenter.y, 12, 0, 2 * Math.PI);
              ctx.fillStyle = eyeCenter.type === 'left' ? '#3B82F6' : '#8B5CF6';
              ctx.fill();
              
              // Draw inner circle
              ctx.beginPath();
              ctx.arc(eyeCenter.x, eyeCenter.y, 6, 0, 2 * Math.PI);
              ctx.fillStyle = 'white';
              ctx.fill();
              
              // Draw crosshair
              ctx.strokeStyle = 'white';
              ctx.lineWidth = 3;
              ctx.beginPath();
              ctx.moveTo(eyeCenter.x - 10, eyeCenter.y);
              ctx.lineTo(eyeCenter.x + 10, eyeCenter.y);
              ctx.moveTo(eyeCenter.x, eyeCenter.y - 10);
              ctx.lineTo(eyeCenter.x, eyeCenter.y + 10);
              ctx.stroke();
            });
          });

          setEyeCenters(detectedEyeCenters);
        } catch (error) {
          console.error('Error drawing on canvas:', error);
          setImageError(true);
        }
      };

      img.onerror = () => {
        clearTimeout(loadTimeout);
        console.error('Failed to load image, attempt:', retryCount + 1);
        if (retryCount < maxRetries) {
          retryCount++;
          setTimeout(loadImage, 1000);
        } else {
          setImageError(true);
          setImageLoaded(false);
        }
      };

      img.src = imageDataUrl;
    };
    
    loadImage();
  }, [faceMeshResults, imageDataUrl]);

  const calculatePreciseEyeCenter = (
    irisLandmarks: any[], 
    cornerLandmarks: any[], 
    canvasWidth: number, 
    canvasHeight: number
  ) => {
    // First try to use iris landmarks for maximum accuracy
    const irisCenter = calculateCenterFromLandmarks(irisLandmarks, canvasWidth, canvasHeight);
    if (irisCenter) {
      return irisCenter;
    }

    // Fallback to geometric center of eye corners if iris landmarks aren't available
    const geometricCenter = calculateGeometricEyeCenter(cornerLandmarks, canvasWidth, canvasHeight);
    return geometricCenter;
  };

  const calculateCenterFromLandmarks = (landmarks: any[], canvasWidth: number, canvasHeight: number) => {
    if (!landmarks || landmarks.length === 0) return null;

    let sumX = 0;
    let sumY = 0;
    let validLandmarks = 0;

    landmarks.forEach((landmark) => {
      if (landmark && 
          landmark.x !== undefined && landmark.y !== undefined &&
          landmark.x >= 0 && landmark.x <= 1 &&
          landmark.y >= 0 && landmark.y <= 1) {
        sumX += landmark.x * canvasWidth;
        sumY += landmark.y * canvasHeight;
        validLandmarks++;
      }
    });

    if (validLandmarks < 2) return null;

    const centerX = sumX / validLandmarks;
    const centerY = sumY / validLandmarks;
    
    // Ensure coordinates are within canvas bounds
    const clampedX = Math.max(0, Math.min(canvasWidth, centerX));
    const clampedY = Math.max(0, Math.min(canvasHeight, centerY));
    
    return {
      x: clampedX,
      y: clampedY,
    };
  };

  const calculateGeometricEyeCenter = (cornerLandmarks: any[], canvasWidth: number, canvasHeight: number) => {
    if (!cornerLandmarks || cornerLandmarks.length < 4) return null;

    const validCorners = cornerLandmarks.filter(landmark => 
      landmark && 
      landmark.x !== undefined && landmark.y !== undefined &&
      landmark.x >= 0 && landmark.x <= 1 &&
      landmark.y >= 0 && landmark.y <= 1
    );

    if (validCorners.length < 3) return null;

    // Calculate the geometric center of the eye shape
    const outerCorner = validCorners[0];
    const innerCorner = validCorners[1];
    const topCenter = validCorners[2];
    const bottomCenter = validCorners[3];

    // Use weighted average focusing on the center of the eye opening
    const centerX = ((outerCorner.x + innerCorner.x) / 2) * canvasWidth;
    const centerY = ((topCenter.y + bottomCenter.y) / 2) * canvasHeight;

    // Ensure coordinates are within canvas bounds
    const clampedX = Math.max(0, Math.min(canvasWidth, centerX));
    const clampedY = Math.max(0, Math.min(canvasHeight, centerY));

    return {
      x: clampedX,
      y: clampedY,
    };
  };

  const downloadResult = () => {
    if (!canvasRef.current) return;
    
    const link = document.createElement('a');
    link.download = 'eye-centers-detected.png';
    link.href = canvasRef.current.toDataURL();
    link.click();
  };

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      {/* Results Display */}
      <div className="bg-white rounded-xl shadow-lg overflow-hidden">
        <div className="p-6 bg-gradient-to-r from-blue-50 to-purple-50 border-b">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="p-2 bg-blue-100 rounded-lg">
                <Eye className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-900">Eye Centers Detected</h2>
                <p className="text-gray-600">
                  Found {eyeCenters.length} eye{eyeCenters.length !== 1 ? 's' : ''} in the image
                </p>
              </div>
            </div>
            
            <div className="flex space-x-2">
              <button
                onClick={downloadResult}
                disabled={!imageLoaded}
                className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Download className="w-4 h-4" />
                <span>Download</span>
              </button>
              
              <button
                onClick={onReset}
                className="flex items-center space-x-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors duration-200"
              >
                <RotateCcw className="w-4 h-4" />
                <span>New Image</span>
              </button>
            </div>
          </div>
        </div>

        <div className="p-6">
          {!imageLoaded && !imageError && (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <span className="ml-3 text-gray-600">Rendering results...</span>
            </div>
          )}
          
          {imageError && (
            <div className="flex flex-col items-center justify-center py-8 space-y-4">
              <div className="text-red-600">
                <AlertCircle className="w-8 h-8" />
              </div>
              <div className="text-center">
                <p className="text-red-700 font-medium">Failed to render image</p>
                <p className="text-red-600 text-sm">Please try uploading a different image</p>
              </div>
              <button
                onClick={onReset}
                className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors duration-200"
              >
                Choose New Image
              </button>
            </div>
          )}
          
          <div className="relative inline-block">
            <canvas
              ref={canvasRef}
              className={`max-w-full h-auto rounded-lg shadow-md transition-opacity duration-300 ${
                imageLoaded && !imageError ? 'opacity-100' : 'opacity-0'
              }`}
            />
          </div>
        </div>
      </div>

      {/* Eye Centers Info */}
      {eyeCenters.length > 0 && (
        <div className="bg-white rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Detected Eye Centers</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {eyeCenters.map((eye, index) => (
              <div
                key={index}
                className="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg"
              >
                <div 
                  className={`w-4 h-4 rounded-full ${
                    eye.type === 'left' ? 'bg-blue-500' : 'bg-purple-500'
                  }`}
                />
                <div>
                  <div className="font-medium text-gray-900 capitalize">
                    {eye.type} Eye
                  </div>
                  <div className="text-sm text-gray-600">
                    X: {Math.round(eye.x)}, Y: {Math.round(eye.y)}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};