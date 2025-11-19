//
//  ContentView.swift
//  BackdropAdmin
//
//  Main content view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var apiClient = APIClient()
    
    var body: some View {
        NavigationView {
            if authManager.isAuthenticated {
                MainView()
                    .environmentObject(authManager)
                    .environmentObject(apiClient)
                    .onAppear {
                        apiClient.setAuthManager(authManager)
                    }
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var apiClient: APIClient
    @State private var showingStatusReport = false
    @State private var cacheClearMessage: String?
    
    var body: some View {
        List {
            Section("Quick Actions") {
                Button(action: {
                    Task {
                        await apiClient.clearCache()
                        cacheClearMessage = "Cache cleared successfully"
                        // Clear message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            cacheClearMessage = nil
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                        if apiClient.isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(apiClient.isLoading)
                
                if let message = cacheClearMessage {
                    Text(message)
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Button(action: {
                    showingStatusReport = true
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Status Report")
                    }
                }
                
                // Placeholder: Run Cron
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.gray)
                    Text("Run Cron")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Content Management") {
                // Placeholder: Content List
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                    Text("Content List")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
                
                // Placeholder: Content Editing
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray)
                    Text("Create Content")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Comments") {
                // Placeholder: Comments Moderation
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(.gray)
                    Text("Moderate Comments")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Files") {
                // Placeholder: File Management
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.gray)
                    Text("File Management")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Blocks") {
                // Placeholder: Block Editing
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.gray)
                    Text("Edit Blocks")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Users") {
                // Placeholder: User Management
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.gray)
                    Text("User Management")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section("Reports") {
                // Placeholder: Log Messages
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.gray)
                    Text("Log Messages")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
                
                // Placeholder: Error Reports
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gray)
                    Text("Error Reports")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(0.6)
            }
            
            Section {
                Button(action: {
                    authManager.logout()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Logout")
                    }
                    .foregroundColor(.red)
                }
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
        .navigationTitle("Backdrop Admin")
        .sheet(isPresented: $showingStatusReport) {
            StatusReportView()
                .environmentObject(apiClient)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
