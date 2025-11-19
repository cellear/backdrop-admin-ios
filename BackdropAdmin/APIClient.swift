//
//  APIClient.swift
//  BackdropAdmin
//
//  API client for Backdrop Admin API
//

import Foundation
import Combine

class APIClient: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String?
    
    private var authManager: AuthManager?
    
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }
    
    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let authManager = authManager,
              let siteURL = authManager.siteURL,
              let baseURL = URL(string: siteURL),
              let url = URL(string: "/api/admin/\(endpoint)", relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Host header if using IP address (for DDev router)
        let host = baseURL.host ?? ""
        let isIPAddress = host.range(of: #"^\d+\.\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
        if isIPAddress {
            request.setValue("backdrop-for-ios.ddev.site", forHTTPHeaderField: "Host")
        }
        
        // Add authentication headers
        let authHeaders = authManager.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    func clearCache() async {
        do {
            let data = try await makeRequest(endpoint: "cache/clear", method: "POST")
            let response = try JSONDecoder().decode(APIResponse<EmptyData>.self, from: data)
            if response.success {
                print("Cache cleared: \(response.message ?? "Success")")
                lastError = nil
            } else {
                lastError = response.message ?? "Unknown error"
            }
        } catch {
            lastError = error.localizedDescription
            print("Error clearing cache: \(error)")
        }
    }
    
    func getStatusReport() async throws -> StatusReport {
        let data = try await makeRequest(endpoint: "reports/status")
        let response = try JSONDecoder().decode(APIResponse<StatusReportData>.self, from: data)
        guard let statusData = response.data else {
            throw APIError.invalidResponse
        }
        return StatusReport(requirements: statusData.requirements)
    }
}

// MARK: - Response Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

struct EmptyData: Codable {}

struct APIErrorResponse: Codable {
    let error: Bool
    let message: String
    let code: Int?
}

struct StatusReportData: Codable {
    let requirements: [Requirement]
}

struct Requirement: Codable {
    let title: String
    let value: String
    let severity: Int?
    let description: String?
}

struct StatusReport {
    let requirements: [Requirement]
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

