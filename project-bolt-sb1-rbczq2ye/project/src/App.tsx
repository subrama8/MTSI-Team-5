import React, { useState } from 'react';
import { Eye, Sparkles, AlertCircle } from 'lucide-react';
import { ImageUpload } from './components/ImageUpload';
import { FaceMeshProcessor } from './components/FaceMeshProcessor';
import { FaceAnalysisResult } from './components/FaceAnalysisResult';

function App() {
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [faceMeshResults, setFaceMeshResults] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  const handleImageSelect = (file: File) => {
    setSelectedImage(file);
    setFaceMeshResults(null);
    setError(null);
    setIsProcessing(true);
  };

  const handleFaceMeshResult = (results: any) => {
    console.log('Received face mesh results:', results);
    setFaceMeshResults(results);
    setIsProcessing(false);
    
    if (!results.multiFaceLandmarks || results.multiFaceLandmarks.length === 0) {
      setError('No faces detected in the image. Please try with a clearer face photo where the face is well-lit, clearly visible, and facing forward.');
    } else {
      console.log(`Detected ${results.multiFaceLandmarks.length} face(s) with landmarks`);
    }
  };

  const handleError = (errorMessage: string) => {
    console.error('Face detection error:', errorMessage);
    setError(errorMessage);
    setIsProcessing(false);
  };
  
  // Add retry functionality
  const handleRetry = () => {
    if (selectedImage) {
      setError(null);
      setIsProcessing(true);
      setFaceMeshResults(null);
      // Force component remount to reinitialize MediaPipe
      setSelectedImage(null);
      setTimeout(() => {
        setSelectedImage(selectedImage);
      }, 500);
    }
  };

  const handleReset = () => {
    setSelectedImage(null);
    setFaceMeshResults(null);
    setError(null);
    setIsProcessing(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg">
              <Eye className="w-8 h-8 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                Eye Center Detection
              </h1>
              <p className="text-gray-600">Powered by Google MediaPipe Face Mesh</p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!selectedImage || (!faceMeshResults && !isProcessing && !error) ? (
          <div className="text-center space-y-8">
            {/* Hero Section */}
            <div className="space-y-4">
              <div className="flex justify-center">
                <div className="p-4 bg-gradient-to-r from-blue-100 to-purple-100 rounded-full">
                  <Sparkles className="w-12 h-12 text-blue-600" />
                </div>
              </div>
              
              <h2 className="text-4xl font-bold text-gray-900">
                Detect Eye Centers with AI
              </h2>
              
              <p className="text-xl text-gray-600 max-w-2xl mx-auto">
                Upload a face photo and let our advanced AI precisely locate the center of each eye using Google's MediaPipe Face Mesh technology.
              </p>
            </div>

            {/* Upload Section */}
            <ImageUpload
              onImageSelect={handleImageSelect}
              isProcessing={isProcessing}
            />

            {/* Features */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
              <div className="text-center p-6 bg-white rounded-xl shadow-sm">
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Eye className="w-6 h-6 text-blue-600" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Precise Detection</h3>
                <p className="text-gray-600">Advanced AI algorithms provide pixel-perfect eye center coordinates</p>
              </div>
              
              <div className="text-center p-6 bg-white rounded-xl shadow-sm">
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Sparkles className="w-6 h-6 text-purple-600" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Real-time Processing</h3>
                <p className="text-gray-600">Fast analysis with immediate visual feedback and results</p>
              </div>
              
              <div className="text-center p-6 bg-white rounded-xl shadow-sm">
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Multiple Faces</h3>
                <p className="text-gray-600">Detect and analyze eye centers in multiple faces simultaneously</p>
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Processing State */}
            {isProcessing && (
              <div className="text-center py-12">
                <div className="inline-flex items-center space-x-3 px-6 py-3 bg-blue-50 rounded-full">
                  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                  <span className="text-blue-700 font-medium">Analyzing face landmarks...</span>
                </div>
              </div>
            )}

            {/* Error State */}
            {error && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-6">
                <div className="flex items-center space-x-3">
                  <AlertCircle className="w-6 h-6 text-red-600" />
                  <div>
                    <h3 className="text-red-900 font-semibold">Detection Error</h3>
                    <p className="text-red-700">{error}</p>
                    <p className="text-red-600 text-sm mt-2">
                      If this persists, try refreshing the page or using a different browser.
                    </p>
                  </div>
                </div>
                <div className="mt-4 flex space-x-3">
                  <button
                    onClick={handleRetry}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200"
                  >
                    Retry Detection
                  </button>
                  <button
                    onClick={handleReset}
                    className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors duration-200"
                  >
                    Choose New Image
                  </button>
                  <button
                    onClick={() => window.location.reload()}
                    className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors duration-200"
                  >
                    Refresh Page
                  </button>
                </div>
              </div>
            )}

            {/* Results */}
            {faceMeshResults && selectedImage && !error && (
              <FaceAnalysisResult
                imageFile={selectedImage}
                faceMeshResults={faceMeshResults}
                onReset={handleReset}
              />
            )}
          </div>
        )}

        {/* Hidden Face Mesh Processor */}
        {selectedImage && (
          <FaceMeshProcessor
            imageFile={selectedImage}
            onResult={handleFaceMeshResult}
            onError={handleError}
          />
        )}
      </main>
    </div>
  );
}

export default App;