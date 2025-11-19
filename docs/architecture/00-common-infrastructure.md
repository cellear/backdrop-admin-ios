# Common Infrastructure

This document describes the shared infrastructure that all features depend on. When implementing individual features, reference the components documented here.

## Overview

The Backdrop Admin iOS app uses a clean MVVM architecture with SwiftUI. All features share common authentication, API communication, and error handling infrastructure.

---

## iOS Client Infrastructure

### 1. Authentication System (`AuthManager.swift`)

**Purpose**: Manages user authentication and session state across the app.

**Location**: `BackdropAdmin/AuthManager.swift`

**Responsibilities**:
- Cookie-based session management
- Login/logout functionality
- URL normalization (HTTP/HTTPS, IP addresses, hostnames)
- Host header injection for DDev compatibility
- Debug information tracking

**Public API**:
```swift
class AuthManager: ObservableObject {
    // Published properties (automatically updates UI)
    @Published var isAuthenticated: Bool
    @Published var siteURL: String?
    @Published var debugInfo: String?

    // Methods
    func login(siteURL: String, username: String, password: String) async throws
    func logout()
    func getAuthHeaders() -> [String: String]
}
```

**Usage Pattern**:
```swift
// Access via @EnvironmentObject in any view
@EnvironmentObject var authManager: AuthManager

// Check authentication state
if authManager.isAuthenticated {
    // User is logged in
}

// Get auth headers for API calls
let headers = authManager.getAuthHeaders()
```

**Features Implemented**:
- ✅ Automatic IP address detection
- ✅ HTTP/HTTPS protocol selection
- ✅ Session cookie extraction from response headers
- ✅ DDev Host header injection for local development
- ✅ Debug panel showing request/response details

**Dependencies for New Features**:
- All features MUST use `authManager.getAuthHeaders()` for authenticated API calls
- Features should observe `authManager.isAuthenticated` to react to logout events
- Features can read `authManager.siteURL` to construct full URLs if needed

---

### 2. API Client (`APIClient.swift`)

**Purpose**: Centralized API communication layer handling all HTTP requests to Backdrop.

**Location**: `BackdropAdmin/APIClient.swift`

**Responsibilities**:
- Making authenticated HTTP requests
- Request/response serialization (JSON)
- Error handling and user-friendly error messages
- Loading state management
- Host header handling for DDev environments

**Public API**:
```swift
class APIClient: ObservableObject {
    // Published properties
    @Published var isLoading: Bool
    @Published var lastError: String?

    // Configuration
    func setAuthManager(_ authManager: AuthManager)

    // Private helper for making requests
    private func makeRequest(endpoint: String, method: String, body: Data?) async throws -> Data

    // Feature-specific methods (add your own here)
    func clearCache() async
    func getStatusReport() async throws -> StatusReport
}
```

**Request Flow**:
1. Feature calls APIClient method (e.g., `clearCache()`)
2. APIClient calls `makeRequest()` with endpoint path
3. `makeRequest()` constructs full URL: `{siteURL}/api/admin/{endpoint}`
4. Adds authentication headers from AuthManager
5. Handles Host header for IP addresses (DDev compatibility)
6. Executes request with URLSession
7. Validates HTTP status codes (200-299 = success)
8. Decodes JSON response
9. Returns typed data or throws error

**Standard Response Format**:
```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}
```

**Error Handling**:
```swift
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
}
```

**Adding a New API Method**:
```swift
// In APIClient.swift
func yourNewMethod() async throws -> YourDataType {
    let data = try await makeRequest(
        endpoint: "your/endpoint",  // becomes /api/admin/your/endpoint
        method: "GET"  // or "POST", "PUT", "DELETE"
    )
    let response = try JSONDecoder().decode(APIResponse<YourDataType>.self, from: data)
    guard let result = response.data else {
        throw APIError.invalidResponse
    }
    return result
}
```

**Dependencies for New Features**:
- All features MUST use APIClient for HTTP communication
- Features should observe `apiClient.isLoading` for loading states
- Features should observe `apiClient.lastError` for error messages
- Features must call `apiClient.setAuthManager()` on initialization

---

### 3. Navigation & Routing (`ContentView.swift`)

**Purpose**: Main app navigation and authentication flow.

**Location**: `BackdropAdmin/ContentView.swift`

**Structure**:
```swift
ContentView
├── if authenticated
│   └── MainView (main menu with sections)
└── else
    └── LoginView
```

**MainView Sections**:
- Quick Actions (cache, status, cron)
- Content Management
- Comments
- Files
- Blocks
- Users
- Reports
- Logout

**Adding a New Feature to Navigation**:
```swift
// In MainView, add a NavigationLink or Button in appropriate section:
NavigationLink(destination: YourFeatureView()) {
    HStack {
        Image(systemName: "your.icon")
        Text("Your Feature")
    }
}
```

**Dependencies for New Features**:
- Features receive `authManager` via `.environmentObject(authManager)`
- Features receive `apiClient` via `.environmentObject(apiClient)`
- Features should use SwiftUI's `NavigationView` for navigation
- Features should use `.sheet()` or `NavigationLink` for detail views

---

### 4. Data Models & Type Safety

**Standard Patterns**:

All data models should:
1. Conform to `Codable` for JSON serialization
2. Use optional properties for nullable server fields
3. Use clear, descriptive property names
4. Match server-side JSON structure exactly (or use `CodingKeys`)

**Example**:
```swift
struct YourDataModel: Codable {
    let id: Int
    let title: String
    let body: String?  // Optional for nullable fields
    let createdAt: String

    // Map different JSON keys if needed
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt = "created_at"  // Snake case -> camel case
    }
}
```

**Array Responses**:
```swift
struct YourListData: Codable {
    let items: [YourDataModel]
    let total: Int
    let page: Int?
}
```

---

## Server Infrastructure (Backdrop CMS)

### 1. Module Structure

**Module Name**: `backdrop_admin_api`

**Location**: `modules/custom/backdrop_admin_api/`

**Required Files**:
```
backdrop_admin_api/
├── backdrop_admin_api.info        # Module metadata
├── backdrop_admin_api.module      # Hook implementations
└── backdrop_admin_api.inc         # Callback functions (optional)
```

**Module Info File** (`backdrop_admin_api.info`):
```ini
name = Backdrop Admin API
description = JSON API endpoints for Backdrop Admin iOS app
backdrop = 1.x
package = Custom
type = module
```

**Module File** (`backdrop_admin_api.module`):
```php
<?php

/**
 * Implements hook_menu().
 */
function backdrop_admin_api_menu() {
  $items = array();

  // Define your API endpoints here
  $items['api/admin/your-endpoint'] = array(
    'title' => 'Your Endpoint',
    'page callback' => 'backdrop_admin_api_your_callback',
    'access arguments' => array('administer site configuration'),
    'type' => MENU_CALLBACK,
  );

  return $items;
}

/**
 * Callback for /api/admin/your-endpoint
 */
function backdrop_admin_api_your_callback() {
  // Set JSON header
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Your logic here
    $data = array(/* your data */);

    $response = array(
      'success' => TRUE,
      'message' => 'Success message',
      'data' => $data,
    );
  } catch (Exception $e) {
    $response = array(
      'success' => FALSE,
      'message' => $e->getMessage(),
      'data' => NULL,
    );
  }

  // Return JSON
  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### 2. Standard Response Format

**All endpoints MUST return this structure**:
```json
{
  "success": true,
  "message": "Optional message",
  "data": {
    // Your data here (can be object, array, or null)
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "message": "Error description",
  "data": null
}
```

### 3. Database Queries

**Basic Query Pattern**:
```php
// SELECT
$result = db_query("SELECT * FROM {node} WHERE type = :type",
  array(':type' => 'page')
);

// INSERT
db_insert('your_table')
  ->fields(array(
    'field1' => $value1,
    'field2' => $value2,
  ))
  ->execute();

// UPDATE
db_update('your_table')
  ->fields(array('field' => $new_value))
  ->condition('id', $id)
  ->execute();

// DELETE
db_delete('your_table')
  ->condition('id', $id)
  ->execute();
```

**Entity Loading** (Nodes, Users, etc.):
```php
// Load a node
$node = node_load($nid);

// Load multiple nodes
$nodes = node_load_multiple($nids);

// Load all nodes of a type
$query = new EntityFieldQuery();
$result = $query
  ->entityCondition('entity_type', 'node')
  ->propertyCondition('type', 'page')
  ->propertyCondition('status', 1)
  ->execute();
```

### 4. Authentication & Security

**Current Implementation**:
- Uses Backdrop's standard session cookies (SESS*)
- Cookies are automatically validated by Backdrop
- All endpoints should use `access arguments` in `hook_menu()`

**Access Control**:
```php
$items['api/admin/endpoint'] = array(
  'page callback' => 'your_callback',
  'access arguments' => array('administer site configuration'),
  // Other admin permissions:
  // - 'administer nodes'
  // - 'administer users'
  // - 'administer comments'
  // - 'administer taxonomy'
);
```

**For MVP**: All endpoints assume admin/user 1 access (permissions checking deferred to later)

### 5. Common Backdrop APIs

**Cache Clearing**:
```php
// Clear all caches
backdrop_flush_all_caches();

// Clear specific cache
cache_clear_all('*', 'cache_page', TRUE);
```

**System Status**:
```php
// Get system requirements
module_load_include('install', 'system');
$requirements = system_requirements('runtime');
```

**Logging**:
```php
watchdog('backdrop_admin_api', 'Message: @message',
  array('@message' => $message),
  WATCHDOG_INFO
);
```

---

## API Endpoint Conventions

### URL Structure
```
{siteURL}/api/admin/{feature}/{action}
```

**Examples**:
- `POST /api/admin/cache/clear`
- `GET /api/admin/reports/status`
- `GET /api/admin/content/list`
- `POST /api/admin/content/create`
- `PUT /api/admin/content/123`
- `DELETE /api/admin/content/123`

### HTTP Methods
- `GET` - Retrieve data (list, detail)
- `POST` - Create or trigger action
- `PUT` - Update existing resource
- `DELETE` - Delete resource

### Pagination (for list endpoints)
```php
// Query parameters: page, limit
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20;
$offset = ($page - 1) * $limit;

$query = db_select('node', 'n')
  ->fields('n')
  ->range($offset, $limit);
```

**Response**:
```json
{
  "success": true,
  "data": {
    "items": [...],
    "total": 150,
    "page": 1,
    "limit": 20,
    "pages": 8
  }
}
```

### Filtering & Search
```php
// Query parameters: search, type, status
$search = isset($_GET['search']) ? $_GET['search'] : '';
$type = isset($_GET['type']) ? $_GET['type'] : '';

if ($search) {
  $query->condition('title', '%' . db_like($search) . '%', 'LIKE');
}
```

---

## Error Handling Patterns

### iOS Client
```swift
do {
    let result = try await apiClient.yourMethod()
    // Success handling
} catch {
    // Error is automatically LocalizedError
    errorMessage = error.localizedDescription
}
```

### Backdrop Server
```php
try {
  // Your logic
  if (!$valid) {
    throw new Exception('Validation failed');
  }

  $response = array('success' => TRUE, 'data' => $data);
} catch (Exception $e) {
  watchdog('backdrop_admin_api', 'Error: @msg',
    array('@msg' => $e->getMessage()),
    WATCHDOG_ERROR
  );

  $response = array(
    'success' => FALSE,
    'message' => $e->getMessage(),
  );
}
```

---

## Loading States & User Feedback

### iOS Pattern
```swift
@State private var isLoading = false
@State private var errorMessage: String?
@State private var successMessage: String?

// In your async function
isLoading = true
defer { isLoading = false }

do {
    try await apiClient.yourMethod()
    successMessage = "Success!"
    // Auto-dismiss after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        successMessage = nil
    }
} catch {
    errorMessage = error.localizedDescription
}
```

### UI Pattern
```swift
if isLoading {
    ProgressView()
} else if let error = errorMessage {
    Text(error).foregroundColor(.red)
} else if let success = successMessage {
    Text(success).foregroundColor(.green)
}
```

---

## Testing

### iOS Testing
- Use Xcode's built-in Preview for UI testing
- Test with both IP addresses and hostnames
- Test with DDev local environment

### Server Testing
- Test endpoints with curl:
```bash
curl -X POST http://your-site/api/admin/cache/clear \
  -H "Cookie: SESS123abc=xyz" \
  -H "Content-Type: application/json"
```

- Use browser dev tools to inspect network requests
- Check Backdrop watchdog logs for errors

---

## Environment-Specific Configuration

### Development (DDev)
- Site URL: IP address (e.g., `http://192.168.30.85`)
- Host header: `backdrop-for-ios.ddev.site`
- HTTP (not HTTPS) to avoid certificate issues

### Production
- Site URL: Full domain (e.g., `https://example.com`)
- No Host header needed
- HTTPS required

### App Transport Security
Currently set to allow arbitrary loads for testing. For production, lock down to specific domains.

---

## Summary for Implementers

When implementing a new feature, you need:

### iOS Side:
1. **View** - SwiftUI view for the UI
2. **API Method** - Add method to `APIClient.swift`
3. **Data Models** - Codable structs for request/response
4. **Navigation** - Add entry point in `MainView`

### Server Side:
1. **Menu Hook** - Add route in `backdrop_admin_api_menu()`
2. **Callback Function** - Implement endpoint logic
3. **Response** - Return standard JSON format
4. **Testing** - Test with curl or browser

### Dependencies:
- Use `@EnvironmentObject var authManager: AuthManager`
- Use `@EnvironmentObject var apiClient: APIClient`
- Use `authManager.getAuthHeaders()` for auth
- Use `makeRequest()` in APIClient for HTTP calls
- Return standard `APIResponse<T>` format

---

## Next Steps

Refer to individual feature architecture documents for specific implementation details:
- `01-cache-clear.md` - Reference implementation (existing)
- `02-status-report.md` - Reference implementation (existing)
- `03-content-list.md` - Content browsing
- `04-content-edit.md` - Content creation/editing
- And more...
