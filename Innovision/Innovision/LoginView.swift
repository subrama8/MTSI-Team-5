import SwiftUI

struct LoginView: View {
    @AppStorage("username") private var username = ""

    var body: some View {
        VStack(spacing: 40) {
            Image("innovisionlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 320)

            Image(systemName: "eye.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 84)
                .foregroundColor(.brandPrimary)

            TextField("Enter your name", text: $username)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            if !username.isEmpty {
                Text("Welcome, \(username)!").bold()
            }
        }
        .padding()
    }
}
