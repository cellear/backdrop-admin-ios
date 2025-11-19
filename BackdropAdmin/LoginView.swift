//
//  LoginView.swift
//  BackdropAdmin
//
//  Login view for Backdrop site
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var siteURL = "http://192.168.30.85"
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
                // Left column: Login form
                Form {
                    Section("Site Configuration") {
                        TextField("Site URL", text: $siteURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    
                    Section("Login") {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    
                    if let error = errorMessage {
                        Section("Error") {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            Task {
                                await login()
                            }
                        }) {
                            HStack {
                                if isLoggingIn {
                                    ProgressView()
                                }
                                Text("Login")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isLoggingIn || siteURL.isEmpty || username.isEmpty || password.isEmpty)
                    }
                    
                    Section {
                        HStack {
                            Spacer()
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Version \(version) (\(build))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: geometry.size.width > 800 ? geometry.size.width * 0.4 : geometry.size.width)
                
                // Right column: Debug info (only show on iPad)
                if geometry.size.width > 800, let debugInfo = authManager.debugInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Debug Info")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        ScrollView {
                            Text(debugInfo)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(width: geometry.size.width * 0.55)
                }
            }
            .padding()
        }
        .navigationTitle("Backdrop Admin")
    }
    
    private func login() async {
        isLoggingIn = true
        errorMessage = nil
        
        do {
            try await authManager.login(siteURL: siteURL, username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoggingIn = false
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

