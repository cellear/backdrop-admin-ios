# Feature: Status Report

**Status**: ✅ **IMPLEMENTED** (Reference Implementation)

**Category**: System Management

---

## Overview

Displays system status and requirements in a native iOS interface. Shows health checks, configuration issues, security warnings, and system information with color-coded severity levels.

**User Story**: As an admin, I want to view the system status report on my iPad so I can quickly identify and troubleshoot issues without loading the web interface.

---

## UI Components

### Main View
`StatusReportView` - Full-screen sheet modal displaying the status report.

### Visual Design
- **Navigation Bar** with "Status Report" title and "Done" button
- **List View** with scrollable requirement rows
- **Loading State** - Centered progress indicator with "Loading status report..." text
- **Error State** - Red exclamation triangle icon with error message
- **Empty State** - "No data" message

### Code Location
`BackdropAdmin/StatusReportView.swift`

### View Hierarchy
```
NavigationView
└── Group (conditional rendering)
    ├── ProgressView (if loading)
    ├── Error View (if error)
    ├── List of RequirementRows (if loaded)
    └── "No data" (if no data)
```

### Requirement Row Component

**Visual Elements**:
- **Icon** - SF Symbol indicating severity
- **Title** - Bold headline text
- **Value** - Secondary text showing current value
- **Description** - Small caption text (optional)
- **Color coding** - Icon and emphasis based on severity

**Severity Mapping**:
| Severity | Color | Icon | Meaning |
|----------|-------|------|---------|
| -1 | Blue | `info.circle` | Informational |
| 0 | Green | `checkmark.circle.fill` | OK |
| 1 | Orange | `exclamationmark.triangle.fill` | Warning |
| 2 | Red | `xmark.circle.fill` | Error |

### Implementation
```swift
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
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadStatusReport()
        }
    }
}
```

### Navigation
Presented as a **sheet modal** from MainView:
```swift
.sheet(isPresented: $showingStatusReport) {
    StatusReportView()
        .environmentObject(apiClient)
}
```

---

## iOS Client Components

### Data Models

**Location**: `BackdropAdmin/APIClient.swift:111-124`

```swift
// Response wrapper from server
struct StatusReportData: Codable {
    let requirements: [Requirement]
}

// Individual requirement/check
struct Requirement: Codable {
    let title: String           // e.g., "PHP version"
    let value: String           // e.g., "8.1.12"
    let severity: Int?          // -1, 0, 1, 2
    let description: String?    // Optional details
}

// View model
struct StatusReport {
    let requirements: [Requirement]
}
```

### API Method

**Location**: `BackdropAdmin/APIClient.swift:85-92`

```swift
func getStatusReport() async throws -> StatusReport {
    let data = try await makeRequest(endpoint: "reports/status")
    let response = try JSONDecoder().decode(APIResponse<StatusReportData>.self, from: data)
    guard let statusData = response.data else {
        throw APIError.invalidResponse
    }
    return StatusReport(requirements: statusData.requirements)
}
```

### Request Details
- **Endpoint**: `reports/status`
- **Full URL**: `{siteURL}/api/admin/reports/status`
- **Method**: `GET`
- **Body**: None
- **Headers**:
  - `Content-Type: application/json`
  - `Cookie: {session cookie from AuthManager}`
  - `Host: {hostname}` (if IP address)

### Response Handling
Expects `APIResponse<StatusReportData>`:
```json
{
  "success": true,
  "message": null,
  "data": {
    "requirements": [
      {
        "title": "PHP",
        "value": "8.1.12",
        "severity": 0,
        "description": "PHP version is adequate"
      },
      {
        "title": "Database",
        "value": "MySQL 5.7.40",
        "severity": 1,
        "description": "Consider upgrading to MySQL 8.0"
      }
    ]
  }
}
```

### Error Handling
- Network errors → Display error state with icon
- JSON decode errors → APIError.invalidResponse
- Missing data → APIError.invalidResponse

---

## Server Components (Backdrop)

### Module
`backdrop_admin_api`

### Route Definition

**Location**: `backdrop_admin_api.module` (in `hook_menu()`)

```php
$items['api/admin/reports/status'] = array(
  'title' => 'System Status Report',
  'page callback' => 'backdrop_admin_api_status_report',
  'access arguments' => array('administer site configuration'),
  'type' => MENU_CALLBACK,
);
```

### Callback Function

```php
/**
 * Callback for GET /api/admin/reports/status
 */
function backdrop_admin_api_status_report() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Load system status requirements
    module_load_include('install', 'system');
    $requirements = system_requirements('runtime');

    // Transform requirements to simple array format
    $formatted_requirements = array();
    foreach ($requirements as $key => $requirement) {
      $formatted_requirements[] = array(
        'title' => $requirement['title'],
        'value' => isset($requirement['value']) ? strip_tags($requirement['value']) : '',
        'severity' => isset($requirement['severity']) ? $requirement['severity'] : REQUIREMENT_INFO,
        'description' => isset($requirement['description']) ? strip_tags($requirement['description']) : '',
      );
    }

    $response = array(
      'success' => TRUE,
      'message' => NULL,
      'data' => array(
        'requirements' => $formatted_requirements,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Status report error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load status report: ' . $e->getMessage(),
      'data' => NULL,
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**None** - Uses Backdrop's built-in `system_requirements()` function which gathers data from various sources.

### Backdrop API Used
- `module_load_include('install', 'system')` - Loads system.install file
- `system_requirements('runtime')` - Gets all runtime requirements
- `strip_tags()` - Removes HTML from descriptions/values
- `backdrop_add_http_header()` - Sets response headers
- `backdrop_json_encode()` - Encodes response as JSON
- `watchdog()` - Logs errors

### Severity Constants
```php
REQUIREMENT_INFO = -1     // Blue (informational)
REQUIREMENT_OK = 0        // Green (passing)
REQUIREMENT_WARNING = 1   // Orange (warning)
REQUIREMENT_ERROR = 2     // Red (critical)
```

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager` - For authentication headers
- ✅ `APIClient` - For HTTP request handling
- ✅ `APIClient.makeRequest()` - Core HTTP method
- ✅ `APIResponse<T>` - Standard response wrapper
- ✅ `Environment(\.dismiss)` - Sheet dismissal

### From Server:
- ✅ `hook_menu()` - Route registration
- ✅ Standard response format
- ✅ Access control via `access arguments`
- ✅ `system_requirements()` - Built-in Backdrop function

---

## API Specification

### Endpoint
```
GET /api/admin/reports/status
```

### Request Headers
```
Content-Type: application/json
Cookie: SESS{hash}={session_id}
Host: {hostname}  (if using IP address)
```

### Request Body
None

### Success Response (200 OK)
```json
{
  "success": true,
  "message": null,
  "data": {
    "requirements": [
      {
        "title": "Backdrop version",
        "value": "1.25.0",
        "severity": 0,
        "description": "Your site is running the latest version"
      },
      {
        "title": "PHP",
        "value": "8.1.12",
        "severity": 0,
        "description": "PHP version is adequate"
      },
      {
        "title": "PHP register globals",
        "value": "Disabled",
        "severity": 0,
        "description": null
      },
      {
        "title": "Database updates",
        "value": "Out of date",
        "severity": 2,
        "description": "Run update.php to apply pending updates"
      }
    ]
  }
}
```

### Error Response (200 OK with error flag)
```json
{
  "success": false,
  "message": "Failed to load status report: {error details}",
  "data": null
}
```

### HTTP Error Responses
- **401 Unauthorized** - Not logged in or session expired
- **403 Forbidden** - Insufficient permissions
- **500 Internal Server Error** - Server-side error

---

## Implementation Notes

### Why This Works Well
1. **Native Experience** - Better than loading web page on mobile
2. **Color Coding** - Visual severity indicators easier to scan
3. **Read-Only** - No complex state management needed
4. **Standard Data** - Uses Backdrop's built-in requirements system

### Design Decisions
1. **Sheet modal instead of push** - Status report is auxiliary info, not main navigation
2. **Auto-load on appear** - Uses `.task {}` modifier for immediate data fetch
3. **No refresh button** - Sheet reopening naturally refreshes
4. **Strip HTML tags** - Converts HTML descriptions to plain text for iOS display
5. **List with ID on title** - Assumes titles are unique (generally true)

### Potential Improvements
- [ ] Pull-to-refresh gesture
- [ ] Tap requirement for full details (expanded view)
- [ ] Filter by severity (show only warnings/errors)
- [ ] Export/share status report
- [ ] Cache results temporarily
- [ ] Add "last updated" timestamp

### Known Issues
- **HTML in descriptions** - Currently stripped, may lose some formatting
- **Title uniqueness** - If two requirements have same title, List may have issues (rare)

---

## Testing Checklist

### iOS Testing
- [ ] Opens as sheet modal from main menu
- [ ] Shows loading state immediately
- [ ] Displays requirements in list
- [ ] Color coding works correctly for all severities
- [ ] "Done" button dismisses sheet
- [ ] Error state displays properly
- [ ] Works on both iPad and iPhone
- [ ] Handles long descriptions gracefully

### Server Testing
```bash
# Test with curl
curl -X GET http://your-site/api/admin/reports/status \
  -H "Content-Type: application/json" \
  -H "Cookie: SESS123abc=xyz"

# Expected response structure
{
  "success": true,
  "data": {
    "requirements": [...]
  }
}
```

### Integration Testing
- [ ] All system requirements appear
- [ ] Severity values are correct
- [ ] HTML is properly stripped from descriptions
- [ ] Permissions are enforced (403 for non-admin)
- [ ] Error logging works (check watchdog)

---

## Related Features
- **Clear Cache** - Also in "Quick Actions"
- **Log Messages** - Planned, similar reporting feature
- **Error Reports** - Planned, similar reporting feature

---

## For AI Implementers

**This feature is already complete** and serves as a reference for implementing data-fetching and display features.

**Key Patterns to Follow**:
1. **Sheet modal for auxiliary views** - Use `.sheet(isPresented:)`
2. **Immediate data loading** - Use `.task {}` modifier
3. **Loading/Error/Success states** - Conditional rendering with `Group`
4. **List-based display** - Use `List` with `id:` parameter
5. **Color coding** - Map data values to UI colors
6. **Custom row components** - Extract reusable `RequirementRow` view
7. **Server-side transformation** - Strip HTML, format data for mobile
8. **Use built-in APIs** - Leverage Backdrop's existing functions

**Similar Features You Could Implement**:
- Log Messages (list with filtering)
- Recent Content (list with editing)
- User List (list with status indicators)
- Comment Queue (list with approve/reject actions)

**Note on List Performance**:
For large datasets (100+ items), consider:
- Pagination on server side
- Lazy loading in iOS
- Search/filter functionality
