//
//  LoginView.swift
//  Innovision
//
//  Created by Stephanie Shen on 7/22/25.
//


import SwiftUI

struct LoginView: View {
    /// Persists across launches in iCloud key‑value store
    @AppStorage("username") private var username = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "eye")
                .resizable().scaledToFit().frame(width: 72)
                .foregroundColor(.skyBlue)

            TextField("Enter your name", text: $username)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if !username.isEmpty {
                Text("Welcome, \(username)!").bold()
            }
        }
        .padding()
    }
}
