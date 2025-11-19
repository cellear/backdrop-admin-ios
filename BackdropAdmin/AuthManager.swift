//
//  AuthManager.swift
//  BackdropAdmin
//
//  Handles authentication with Backdrop site
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var siteURL: String?
    @Published var debugInfo: String?
    
    private var sessionCookie: String?
    
    func login(siteURL: String, username: String, password: String) async throws {
        // Normalize URL
        var urlString = siteURL.trimmingCharacters(in: .whitespaces)
        
        // Check if it's an IP address (before adding protocol)
        let tempURL = urlString.hasPrefix("http://") || urlString.hasPrefix("https://") 
            ? urlString 
            : "http://\(urlString)"
        let tempBaseURL = URL(string: tempURL)
        let host = tempBaseURL?.host ?? ""
        let isIPAddress = host.range(of: #"^\d+\.\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
        
        // Add protocol if missing
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // Use HTTP for IP addresses (avoids certificate issues with self-signed certs)
            // Use HTTPS for hostnames
            urlString = isIPAddress ? "http://" + urlString : "https://" + urlString
        } else if isIPAddress && urlString.hasPrefix("https://") {
            // Convert HTTPS to HTTP for IP addresses to avoid certificate errors
            urlString = urlString.replacingOccurrences(of: "https://", with: "http://")
        }
        
        guard let baseURL = URL(string: urlString) else {
            throw AuthError.invalidURL
        }
        
        // Extract hostname from original URL if it was provided, otherwise use default for DDev
        var hostnameForHeader: String?
        if isIPAddress {
            // If URL is an IP, try to extract hostname from original URL string
            // Look for common DDev patterns
            if urlString.contains("backdrop-for-ios.ddev.site") {
                hostnameForHeader = "backdrop-for-ios.ddev.site"
            } else if let originalHost = URL(string: urlString)?.host, !originalHost.isEmpty {
                // Try to find hostname in the original string before normalization
                let originalURL = siteURL.trimmingCharacters(in: .whitespaces)
                if let url = URL(string: originalURL), let host = url.host, !host.isEmpty {
                    hostnameForHeader = host
                } else if originalURL.contains(".ddev.site") {
                    // Extract hostname from string
                    if let range = originalURL.range(of: #"[a-zA-Z0-9-]+\.ddev\.site"#, options: .regularExpression) {
                        hostnameForHeader = String(originalURL[range])
                    }
                }
            }
            // Default fallback for local DDev testing
            if hostnameForHeader == nil {
                hostnameForHeader = "backdrop-for-ios.ddev.site"
            }
        }
        
        // Login endpoint
        guard let loginURL = URL(string: "/user/login", relativeTo: baseURL) else {
            throw AuthError.invalidURL
        }
        
        // Debug: Log the URL being used
        var debugMessages = ["Request URL: \(loginURL.absoluteString)"]
        if let hostHeader = hostnameForHeader {
            debugMessages.append("Adding Host header: \(hostHeader)")
        }
        
        // Create URLSession with cookie handling
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Add Host header if using IP address
        if let hostHeader = hostnameForHeader {
            request.setValue(hostHeader, forHTTPHeaderField: "Host")
        }
        
        // Build form data
        let formData = "name=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&pass=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&form_id=user_login_form"
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            debugMessages.append("Error: Response is not HTTPURLResponse")
            self.debugInfo = debugMessages.joined(separator: "\n")
            throw AuthError.invalidResponse
        }
        
        // Debug: Log status code and headers
        debugMessages.append("HTTP Status: \(httpResponse.statusCode)")
        debugMessages.append("Response Headers:")
        for (key, value) in httpResponse.allHeaderFields {
            debugMessages.append("  \(key): \(value)")
        }
        
        // Debug: Log response body (first 500 chars)
        if let responseBody = String(data: data, encoding: .utf8) {
            let preview = String(responseBody.prefix(500))
            debugMessages.append("Response Body (first 500 chars):")
            debugMessages.append(preview)
        }
        
        // Extract session cookie from response headers
        if let setCookieHeaders = httpResponse.allHeaderFields["Set-Cookie"] as? String {
            // Parse Set-Cookie header
            let cookies = setCookieHeaders.components(separatedBy: ",")
            for cookieString in cookies {
                let parts = cookieString.trimmingCharacters(in: .whitespaces).components(separatedBy: ";")
                if let nameValue = parts.first {
                    let nameValueParts = nameValue.components(separatedBy: "=")
                    if nameValueParts.count == 2 {
                        let name = nameValueParts[0].trimmingCharacters(in: .whitespaces)
                        let value = nameValueParts[1].trimmingCharacters(in: .whitespaces)
                        if name.hasPrefix("SESS") {
                            sessionCookie = "\(name)=\(value)"
                            break
                        }
                    }
                }
            }
        }
        
        // Also check HTTPCookieStorage
        if sessionCookie == nil {
            if let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) {
                for cookie in cookies {
                    if cookie.name.hasPrefix("SESS") {
                        sessionCookie = "\(cookie.name)=\(cookie.value)"
                        break
                    }
                }
            }
        }
        
        // Check if login was successful (302 redirect or 200 with success)
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
            if sessionCookie != nil {
                debugMessages.append("✓ Session cookie found: \(sessionCookie!)")
                self.debugInfo = debugMessages.joined(separator: "\n")
                self.isAuthenticated = true
                self.siteURL = urlString
            } else {
                debugMessages.append("✗ No session cookie found")
                self.debugInfo = debugMessages.joined(separator: "\n")
                throw AuthError.loginFailed
            }
        } else {
            debugMessages.append("✗ Login failed - Status code: \(httpResponse.statusCode)")
            self.debugInfo = debugMessages.joined(separator: "\n")
            throw AuthError.loginFailed
        }
    }
    
    func logout() {
        isAuthenticated = false
        siteURL = nil
        sessionCookie = nil
        debugInfo = nil
    }
    
    func getAuthHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        if let cookie = sessionCookie {
            headers["Cookie"] = cookie
        }
        return headers
    }
}

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid site URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .loginFailed:
            return "Login failed. Please check your credentials."
        }
    }
}

