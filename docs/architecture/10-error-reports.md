# Feature: Error Reports

**Status**: 📋 **PLANNED**

**Category**: System Management

---

## Overview

View recent PHP errors, warnings, and notices from the Backdrop watchdog log. Filter by severity, search by message, and view detailed error information.

**User Story**: As an admin, I want to view recent errors on my iPad so I can quickly identify and troubleshoot site issues.

---

## UI Components

### Main View
`ErrorReportsView` - List of log messages with filtering and search.

### Visual Design
- **Navigation Bar** with "Error Reports" title and filter button
- **Severity Tabs** - Emergency, Error, Warning, Notice, All
- **Search Bar** - Search log messages
- **Log List** - Color-coded rows with severity, message, timestamp
- **Detail Sheet** - Full error details with stack trace
- **Empty State** - "No errors found" (good news!)
- **Pull-to-Refresh** - Reload logs

### View Hierarchy
```
NavigationView
└── VStack
    ├── Picker (Severity tabs)
    ├── SearchBar
    └── List
        ├── LogEntryRow (repeating)
        └── LoadMoreButton
```

### Log Entry Row Component

**Visual Elements**:
- **Severity Icon** - Color-coded symbol
- **Message** - Truncated to 2 lines
- **Timestamp** - Relative time (2 hours ago)
- **Type Badge** - PHP, System, User, etc.
- **Details Indicator** - Chevron for more info

**Severity Color Coding**:
| Level | Color | Icon | Backdrop Constant |
|-------|-------|------|-------------------|
| Emergency | Red | `exclamationmark.octagon.fill` | WATCHDOG_EMERGENCY (0) |
| Alert | Red | `exclamationmark.triangle.fill` | WATCHDOG_ALERT (1) |
| Critical | Red | `xmark.circle.fill` | WATCHDOG_CRITICAL (2) |
| Error | Orange | `exclamationmark.circle` | WATCHDOG_ERROR (3) |
| Warning | Yellow | `exclamationmark.triangle` | WATCHDOG_WARNING (4) |
| Notice | Blue | `info.circle` | WATCHDOG_NOTICE (5) |
| Info | Blue | `info.circle.fill` | WATCHDOG_INFO (6) |
| Debug | Gray | `ladybug` | WATCHDOG_DEBUG (7) |

### Detail Sheet
- **Full Message** - Complete error text
- **Type** - Module/component that logged error
- **Severity** - Level name
- **Timestamp** - Full date/time
- **User** - User who triggered error (if applicable)
- **IP Address** - Request IP
- **Request URI** - Page where error occurred
- **Referer** - Previous page
- **Variables** - Serialized error context (formatted)
- **Copy Button** - Copy error details

---

## iOS Client Components

### Data Models

```swift
// Log list response
struct LogListData: Codable {
    let items: [LogEntry]
    let total: Int
    let page: Int
    let limit: Int
    let counts: SeverityCounts  // Count per severity level
}

// Severity counts for tab badges
struct SeverityCounts: Codable {
    let emergency: Int
    let alert: Int
    let critical: Int
    let error: Int
    let warning: Int
    let notice: Int
    let info: Int
    let debug: Int
}

// Individual log entry
struct LogEntry: Codable, Identifiable {
    let id: Int             // Watchdog ID
    let type: String        // Module/type (php, cron, user, etc.)
    let message: String     // Message with placeholders
    let variables: String?  // Serialized variables
    let severity: Int       // 0-7 (see table above)
    let link: String?       // Optional link
    let location: String    // Request URI
    let referer: String?    // HTTP referer
    let hostname: String    // IP address
    let timestamp: Int      // Unix timestamp
    let uid: Int            // User ID who triggered

    enum CodingKeys: String, CodingKey {
        case id = "wid"
        case type, message, variables, severity, link, location
        case referer, hostname, timestamp, uid
    }

    // Computed properties
    var severityColor: Color {
        switch severity {
        case 0...2: return .red     // Emergency, Alert, Critical
        case 3: return .orange       // Error
        case 4: return .yellow       // Warning
        case 5...6: return .blue     // Notice, Info
        default: return .gray        // Debug
        }
    }

    var severityName: String {
        switch severity {
        case 0: return "Emergency"
        case 1: return "Alert"
        case 2: return "Critical"
        case 3: return "Error"
        case 4: return "Warning"
        case 5: return "Notice"
        case 6: return "Info"
        case 7: return "Debug"
        default: return "Unknown"
        }
    }

    var severityIcon: String {
        switch severity {
        case 0: return "exclamationmark.octagon.fill"
        case 1...2: return "exclamationmark.triangle.fill"
        case 3: return "exclamationmark.circle"
        case 4: return "exclamationmark.triangle"
        case 5...6: return "info.circle"
        default: return "ladybug"
        }
    }

    // Format message with variables
    func formattedMessage() -> String {
        guard let vars = variables,
              let data = vars.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return message
        }

        var formatted = message
        for (key, value) in decoded {
            formatted = formatted.replacingOccurrences(of: key, with: value)
        }
        return formatted
    }
}
```

### View Model

```swift
class ErrorReportsViewModel: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSeverity: Int? = 3  // Default to errors
    @Published var searchText: String = ""
    @Published var counts = SeverityCounts(
        emergency: 0, alert: 0, critical: 0, error: 0,
        warning: 0, notice: 0, info: 0, debug: 0
    )

    private let apiClient: APIClient

    func loadLogs() async {
        // Load logs with filters
    }

    func refresh() async {
        // Reload logs
    }

    func clearLogs() async throws {
        // Clear all log entries (with confirmation)
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get logs
func getLogs(
    page: Int = 1,
    limit: Int = 50,
    severity: Int? = nil,
    search: String? = nil,
    type: String? = nil
) async throws -> LogListData {
    var queryParams: [String] = []
    queryParams.append("page=\(page)")
    queryParams.append("limit=\(limit)")
    if let severity = severity {
        queryParams.append("severity=\(severity)")
    }
    if let search = search, !search.isEmpty {
        queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    if let type = type {
        queryParams.append("type=\(type)")
    }

    let queryString = queryParams.joined(separator: "&")
    let endpoint = "reports/logs?\(queryString)"

    let data = try await makeRequest(endpoint: endpoint, method: "GET")
    let response = try JSONDecoder().decode(APIResponse<LogListData>.self, from: data)
    guard let logData = response.data else {
        throw APIError.invalidResponse
    }
    return logData
}

// Clear logs
func clearLogs() async throws {
    _ = try await makeRequest(endpoint: "reports/logs/clear", method: "POST")
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// List logs
$items['api/admin/reports/logs'] = array(
  'title' => 'Error Logs',
  'page callback' => 'backdrop_admin_api_log_list',
  'access arguments' => array('access site reports'),
  'type' => MENU_CALLBACK,
);

// Clear logs
$items['api/admin/reports/logs/clear'] = array(
  'title' => 'Clear Logs',
  'page callback' => 'backdrop_admin_api_log_clear',
  'access arguments' => array('administer site configuration'),
  'type' => MENU_CALLBACK,
);
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/reports/logs
 */
function backdrop_admin_api_log_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? min(500, max(1, (int)$_GET['limit'])) : 50;
    $severity = isset($_GET['severity']) ? (int)$_GET['severity'] : NULL;
    $search = isset($_GET['search']) ? $_GET['search'] : NULL;
    $type = isset($_GET['type']) ? $_GET['type'] : NULL;

    $offset = ($page - 1) * $limit;

    // Build query
    $query = db_select('watchdog', 'w')
      ->fields('w')
      ->orderBy('wid', 'DESC')
      ->range($offset, $limit);

    // Severity filter
    if ($severity !== NULL) {
      $query->condition('severity', $severity);
    }

    // Type filter
    if ($type) {
      $query->condition('type', $type);
    }

    // Search filter
    if ($search) {
      $query->condition('message', '%' . db_like($search) . '%', 'LIKE');
    }

    $results = $query->execute();

    // Get total count
    $count_query = db_select('watchdog', 'w');
    if ($severity !== NULL) {
      $count_query->condition('severity', $severity);
    }
    if ($type) {
      $count_query->condition('type', $type);
    }
    if ($search) {
      $count_query->condition('message', '%' . db_like($search) . '%', 'LIKE');
    }
    $total = $count_query->countQuery()->execute()->fetchField();

    // Get counts by severity
    $counts = array(
      'emergency' => 0,
      'alert' => 0,
      'critical' => 0,
      'error' => 0,
      'warning' => 0,
      'notice' => 0,
      'info' => 0,
      'debug' => 0,
    );

    for ($i = 0; $i <= 7; $i++) {
      $count = db_query("SELECT COUNT(*) FROM {watchdog} WHERE severity = :sev",
        array(':sev' => $i)
      )->fetchField();

      switch ($i) {
        case WATCHDOG_EMERGENCY: $counts['emergency'] = (int)$count; break;
        case WATCHDOG_ALERT: $counts['alert'] = (int)$count; break;
        case WATCHDOG_CRITICAL: $counts['critical'] = (int)$count; break;
        case WATCHDOG_ERROR: $counts['error'] = (int)$count; break;
        case WATCHDOG_WARNING: $counts['warning'] = (int)$count; break;
        case WATCHDOG_NOTICE: $counts['notice'] = (int)$count; break;
        case WATCHDOG_INFO: $counts['info'] = (int)$count; break;
        case WATCHDOG_DEBUG: $counts['debug'] = (int)$count; break;
      }
    }

    // Format results
    $items = array();
    foreach ($results as $row) {
      $items[] = array(
        'wid' => (int)$row->wid,
        'type' => $row->type,
        'message' => $row->message,
        'variables' => $row->variables,
        'severity' => (int)$row->severity,
        'link' => $row->link,
        'location' => $row->location,
        'referer' => $row->referer,
        'hostname' => $row->hostname,
        'timestamp' => (int)$row->timestamp,
        'uid' => (int)$row->uid,
      );
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'items' => $items,
        'total' => (int)$total,
        'page' => $page,
        'limit' => $limit,
        'counts' => $counts,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Log list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load logs: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/reports/logs/clear
 */
function backdrop_admin_api_log_clear() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Clear watchdog table
    db_truncate('watchdog')->execute();

    $response = array(
      'success' => TRUE,
      'message' => 'All log entries cleared successfully',
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Log clear error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to clear logs: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**Existing tables**:
- `watchdog` - System log storage

### Backdrop API Used
- `db_select()` - Query builder
- `db_truncate()` - Clear table
- Watchdog severity constants

---

## API Specification

### List Logs
```
GET /api/admin/reports/logs?page=1&limit=50&severity=3
```

**Response**: (See LogListData model)

### Clear Logs
```
POST /api/admin/reports/logs/clear
```

---

## For AI Implementers

### iOS Tasks:
1. Create `ErrorReportsView.swift`
2. Create `LogEntryDetailSheet.swift`
3. Implement severity tabs with badges
4. Add search and filtering
5. Handle message formatting with variables
6. Add clear logs with confirmation
7. Color-code severity levels

### Server Tasks:
1. Add routes
2. Implement list/clear callbacks
3. Calculate severity counts
4. Handle variable serialization
5. Test with various log types
