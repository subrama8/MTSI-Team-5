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
        
        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to connect to MJPEG stream")
                return
            }
            
            var buffer = Data()
            let boundary = "--jpgboundary"
            
            for try await byte in asyncBytes {
                if Task.isCancelled { break }
                
                buffer.append(byte)
                
                // Look for JPEG start and end markers
                if let boundaryRange = buffer.range(of: boundary.data(using: .utf8)!) {
                    // Process the data after the boundary
                    let afterBoundary = buffer[boundaryRange.upperBound...]
                    
                    // Look for double CRLF (end of headers)
                    if let headerEnd = afterBoundary.range(of: "\r\n\r\n".data(using: .utf8)!) {
                        let imageData = afterBoundary[headerEnd.upperBound...]
                        
                        // Look for next boundary to find end of image
                        if let nextBoundary = imageData.range(of: boundary.data(using: .utf8)!) {
                            let jpegData = imageData[..<nextBoundary.lowerBound]
                            
                            // Create UIImage from JPEG data
                            if let image = UIImage(data: jpegData) {
                                await MainActor.run {
                                    currentImage = image
                                }
                            }
                            
                            // Keep remaining data for next frame
                            buffer = Data(imageData[nextBoundary.lowerBound...])
                        }
                    }
                }
                
                // Prevent buffer from growing too large
                if buffer.count > 1024 * 1024 { // 1MB limit
                    buffer.removeFirst(buffer.count / 2)
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
