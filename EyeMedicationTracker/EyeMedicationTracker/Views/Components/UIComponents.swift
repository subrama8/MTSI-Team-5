import SwiftUI

// MARK: - Card View
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color("LightBlue"))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(Color("LightBlue"))
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("LightBlue").opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Toggle Switch Style
struct LargeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(configuration.isOn ? Color("LightBlue") : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 60)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 50, height: 50)
                    .offset(x: configuration.isOn ? 25 : -25)
                    .shadow(radius: 2)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isOn)
        }
        .accessibilityLabel(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to toggle")
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String
    let activeColor: Color
    let inactiveColor: Color
    
    init(
        isActive: Bool,
        activeText: String = "Active",
        inactiveText: String = "Inactive",
        activeColor: Color = .green,
        inactiveColor: Color = .red
    ) {
        self.isActive = isActive
        self.activeText = activeText
        self.inactiveText = inactiveText
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 12, height: 12)
            
            Text(isActive ? activeText : inactiveText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(isActive ? activeText : inactiveText)")
    }
}

// MARK: - Loading Indicator
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Color("LightBlue")))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading: \(message)")
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let systemImage: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        _ title: String,
        systemImage: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundColor(Color("LightBlue"))
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("LightBlue"))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Accessibility Extensions
extension View {
    func accessibilityLargeContentViewer() -> some View {
        self.modifier(LargeContentViewModifier())
    }
}

struct LargeContentViewModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    
    func body(content: Content) -> some View {
        content
            .font(sizeCategory.isAccessibilityCategory ? .title : .body)
    }
}

// MARK: - Color Extensions
extension Color {
    static let lightBlue = Color("LightBlue")
    static let cardBackground = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
}

// MARK: - Preview Helpers
struct PreviewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .environmentObject(ArduinoService.shared)
        .environmentObject(NotificationManager.shared)
    }
}

#Preview("Card View") {
    CardView {
        VStack {
            Text("Sample Card")
                .font(.headline)
            Text("This is a sample card with some content")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        Button("Primary Button") { }
            .buttonStyle(PrimaryButtonStyle())
        
        Button("Secondary Button") { }
            .buttonStyle(SecondaryButtonStyle())
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        title: "No Items Found",
        message: "There are no items to display at this time",
        systemImage: "tray",
        actionTitle: "Add Item"
    ) {
        print("Add item tapped")
    }
}