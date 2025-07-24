//
//  CameraView.swift
//  Innovision
//
//  Created by Stephanie Shen on 7/23/25.
//


import SwiftUI
import AVKit

struct CameraView: View {
    @EnvironmentObject private var device: DeviceService
    @State private var player: AVPlayer?
    @State private var isPlayerReady = false

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
                VideoPlayer(player: player)
                    .frame(height: 320)
                    .cornerRadius(18)
                    .shadow(radius: 6)
                    .onAppear {
                        setupPlayer(with: streamURL)
                    }
                    .onChange(of: device.cameraStreamURL) { newURL in
                        if let url = newURL {
                            setupPlayer(with: url)
                        }
                    }
                    .onDisappear {
                        player?.pause()
                    }
                    .overlay(
                        // Loading indicator
                        Group {
                            if !isPlayerReady {
                                ProgressView("Loading camera feed...")
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                        }
                    )
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
    
    private func setupPlayer(with url: URL) {
        player?.pause()
        player = AVPlayer(url: url)
        isPlayerReady = false
        
        // Start playing
        player?.play()
        
        // Set ready after a short delay (MJPEG streams start immediately)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPlayerReady = true
        }
    }
}
