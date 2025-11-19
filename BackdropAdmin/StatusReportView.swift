//
//  StatusReportView.swift
//  BackdropAdmin
//
//  Status report view
//

import SwiftUI

struct StatusReportView: View {
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) var dismiss
    @State private var statusReport: StatusReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading status report...")
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .padding()
                    }
                } else if let report = statusReport {
                    List(report.requirements, id: \.title) { requirement in
                        RequirementRow(requirement: requirement)
                    }
                } else {
                    Text("No data")
                }
            }
            .navigationTitle("Status Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadStatusReport()
        }
    }
    
    private func loadStatusReport() async {
        isLoading = true
        errorMessage = nil
        
        do {
            statusReport = try await apiClient.getStatusReport()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct RequirementRow: View {
    let requirement: Requirement
    
    var severityColor: Color {
        guard let severity = requirement.severity else { return .primary }
        switch severity {
        case -1: return .blue      // Info
        case 0: return .green      // OK
        case 1: return .orange     // Warning
        case 2: return .red        // Error
        default: return .primary
        }
    }
    
    var severityIcon: String {
        guard let severity = requirement.severity else { return "circle" }
        switch severity {
        case -1: return "info.circle"
        case 0: return "checkmark.circle.fill"
        case 1: return "exclamationmark.triangle.fill"
        case 2: return "xmark.circle.fill"
        default: return "circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                Text(requirement.title)
                    .font(.headline)
                Spacer()
            }
            
            Text(requirement.value)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let description = requirement.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StatusReportView()
        .environmentObject(APIClient())
}

