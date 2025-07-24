//
//  CameraView.swift
//  Innovision
//
//  Created by Stephanie Shen on 7/23/25.
//


import SwiftUI
import AVKit
import UIKit

struct CameraView: View {
    @EnvironmentObject private var device: DeviceService
    @State private var currentImage: UIImage?
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 28) {
            // Camera connection status
            HStack {
                Image(systemName: device.cameraConnected ? "camera.fill" : "camera.slash")
                    .foregroundColor(device.cameraConnected ? .green : .orange)
                Text(device.cameraConnected ? "Camera Connected" : "Searching for Camera...")
                    .foregroundColor(device.cameraConnected ? .green : .orange)
                Spacer()
                if !device.discoveredCameraHosts.isEmpty {
                    Text("\(device.discoveredCameraHosts.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Camera stream
            if device.cameraConnected, let streamURL = device.cameraStreamURL {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 320)
                        .cornerRadius(18)
                    
                    if let image = currentImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 320)
                            .cornerRadius(18)
                    } else {
                        ProgressView("Connecting to camera...")
                            .foregroundColor(.white)
                    }
                }
                .shadow(radius: 6)
                .onAppear {
                    startMJPEGStream(url: streamURL)
                }
                .onChange(of: device.cameraStreamURL) { newURL in
                    if let url = newURL {
                        startMJPEGStream(url: url)
                    }
                }
                .onDisappear {
                    stopMJPEGStream()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("Camera Server Not Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Make sure the camera server is running on your laptop:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("python3 camera_http_server.py")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                    
                    Button("Retry Discovery") {
                        device.startCameraDiscovery()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 40)
            }
            
            // Discovery info
            if !device.discoveredCameraHosts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Camera Servers:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(device.discoveredCameraHosts, id: \.self) { host in
                        HStack {
                            Text("📷 \(host):8081")
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            if device.cameraStreamURL?.host == host {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Button("Connect") {
                                    device.connectToCamera(host: host)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Live Camera")
        .onAppear {
            device.startCameraDiscovery()
        }
        .onDisappear {
            device.stopCameraDiscovery()
        }
    }
    
    private func startMJPEGStream(url: URL) {
        stopMJPEGStream()
        
        streamingTask = Task {
            await streamMJPEG(from: url)
        }
    }
    
    private func stopMJPEGStream() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        currentImage = nil
    }
    
    private func streamMJPEG(from url: URL) async {
        isStreaming = true
        print("🎥 Starting MJPEG stream from: \(url)")
        
        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to connect to MJPEG stream - Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            print("✅ Connected to MJPEG stream")
            var buffer = Data()
            let boundary = Data("--jpgboundary".utf8)
            let doubleNewline = Data("\r\n\r\n".utf8)
            let jpegStart = Data([0xFF, 0xD8]) // JPEG start marker
            
            for try await byte in asyncBytes {
                if Task.isCancelled { break }
                
                buffer.append(byte)
                
                // Look for JPEG data directly (more reliable than boundary parsing)
                if let jpegStartIndex = buffer.range(of: jpegStart)?.lowerBound {
                    // Found start of JPEG, look for end
                    let jpegData = buffer[jpegStartIndex...]
                    
                    // Try to create image from current data
                    let testData = Data(jpegData.prefix(min(jpegData.count, 500000))) // Max 500KB per frame
                    
                    if let image = UIImage(data: testData) {
                        await MainActor.run {
                            self.currentImage = image
                            print("📸 Frame updated - Image size: \(image.size)")
                        }
                        
                        // Clear buffer after successful image
                        buffer.removeAll()
                    } else if jpegData.count > 1000000 { // 1MB limit
                        // Buffer too large, clear it
                        buffer.removeAll()
                    }
                }
                
                // Prevent excessive memory usage
                if buffer.count > 2000000 { // 2MB absolute limit
                    print("⚠️ Buffer overflow, clearing...")
                    buffer.removeAll()
                }
            }
            
        } catch {
            if !Task.isCancelled {
                print("❌ MJPEG streaming error: \(error)")
            }
            await MainActor.run {
                isStreaming = false
            }
        }
    }
}
