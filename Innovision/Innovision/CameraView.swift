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

    // Replace with actual MJPEG or HLS stream URL
    private let streamURL = URL(string: "http://192.168.4.1:8081/stream.m3u8")!

    var body: some View {
        VStack(spacing: 28) {
            if device.isRunning {
                VideoPlayer(player: player)
                    .frame(height: 320)
                    .cornerRadius(18)
                    .shadow(radius: 6)
                    .onAppear {
                        if player == nil { player = AVPlayer(url: streamURL) }
                        player?.play()
                    }
                    .onDisappear { player?.pause() }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Start the device to view the live camera.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 80)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Live Camera")
    }
}
