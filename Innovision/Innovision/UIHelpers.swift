import SwiftUI

// MARK: – Common font
struct SeniorFont: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(.body, design: .rounded))
    }
}

// MARK: – Large, senior‑friendly button
struct BigButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .modifier(SeniorFont())
            .foregroundColor(.white)
            .background(Color.skyBlue)                // uses skyBlue from Colors.swift
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: – Circular progress ring
struct ProgressRing: View {
    let progress: Double        // 0‥1
    let baseColor: Color
    let allDone: Bool

    var body: some View {
        ZStack {
            Circle().stroke(baseColor.opacity(0.15), lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(allDone ? .green : baseColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
        .frame(width: 120, height: 120)
    }
}
