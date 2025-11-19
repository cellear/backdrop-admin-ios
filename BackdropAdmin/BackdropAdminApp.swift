//
//  BackdropAdminApp.swift
//  BackdropAdmin
//
//  Created for Backdrop CMS Admin
//

import SwiftUI

@main
struct BackdropAdminApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
