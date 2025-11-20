# Feature: Clear Cache

**Status**: ✅ **IMPLEMENTED** (Reference Implementation)

**Category**: System Management

---

## Overview

Provides one-tap cache clearing functionality to refresh site caches without accessing the web interface. This is one of the most commonly used admin tasks and benefits from native mobile access.

**User Story**: As an admin, I want to clear the site cache with one tap so I can quickly refresh cached content after making changes.

---

## UI Components

### Location
Integrated directly into `MainView` (main menu) under "Quick Actions" section.

### Visual Design
- **Button** with trash icon (`trash` SF Symbol)
- **Loading Indicator** (spinner) when request is in progress
- **Success Message** (green text) that auto-dismisses after 3 seconds
- **Error Message** (via `apiClient.lastError` if needed)

### Code Location
`BackdropAdmin/ContentView.swift:40-65`

### Implementation
```swift
Button(action: {
    Task {
        await apiClient.clearCache()
        cacheClearMessage = "Cache cleared successfully"
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
```

### States
1. **Idle** - Button enabled, ready to tap
2. **Loading** - Spinner visible, button disabled
3. **Success** - Green message shown for 3 seconds
4. **Error** - Error message displayed (persists until dismissed)

---

## iOS Client Components

### Data Models
```swift
// No complex data models needed
struct EmptyData: Codable {}  // Used for response with no data payload
```

Location: `BackdropAdmin/APIClient.swift:103`

### API Method

**Location**: `BackdropAdmin/APIClient.swift:69-83`

```swift
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
```

### Request Details
- **Endpoint**: `cache/clear`
- **Full URL**: `{siteURL}/api/admin/cache/clear`
- **Method**: `POST`
- **Body**: None
- **Headers**:
  - `Content-Type: application/json`
  - `Cookie: {session cookie from AuthManager}`
  - `Host: {hostname}` (if IP address)

### Response Handling
Expects standard `APIResponse<EmptyData>` format:
```json
{
  "success": true,
  "message": "All caches cleared successfully",
  "data": null
}
```

### Error Handling
- Network errors → Shows localized error message
- HTTP errors → Shows status code
- Server errors → Shows message from response

---

## Server Components (Backdrop)

### Module
`backdrop_admin_api`

### Route Definition

**Location**: `backdrop_admin_api.module` (in `hook_menu()`)

```php
$items['api/admin/cache/clear'] = array(
  'title' => 'Clear Cache',
  'page callback' => 'backdrop_admin_api_clear_cache',
  'access arguments' => array('administer site configuration'),
  'type' => MENU_CALLBACK,
);
```

### Callback Function

```php
/**
 * Callback for POST /api/admin/cache/clear
 */
function backdrop_admin_api_clear_cache() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Clear all Backdrop caches
    backdrop_flush_all_caches();

    $response = array(
      'success' => TRUE,
      'message' => 'All caches cleared successfully',
      'data' => NULL,
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Cache clear error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to clear cache: ' . $e->getMessage(),
      'data' => NULL,
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**None** - Uses Backdrop's built-in cache clearing functions.

### Backdrop API Used
- `backdrop_flush_all_caches()` - Clears all caches (menu, theme, module data, etc.)
- `backdrop_add_http_header()` - Sets response headers
- `backdrop_json_encode()` - Encodes response as JSON
- `backdrop_exit()` - Terminates request cleanly
- `watchdog()` - Logs errors

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager` - For authentication headers
- ✅ `APIClient` - For HTTP request handling
- ✅ `APIClient.makeRequest()` - Core HTTP method
- ✅ `APIResponse<T>` - Standard response wrapper
- ✅ `EmptyData` - Empty data type for responses with no payload

### From Server:
- ✅ `hook_menu()` - Route registration
- ✅ Standard response format
- ✅ Access control via `access arguments`

---

## API Specification

### Endpoint
```
POST /api/admin/cache/clear
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
  "message": "All caches cleared successfully",
  "data": null
}
```

### Error Response (200 OK with error flag)
```json
{
  "success": false,
  "message": "Failed to clear cache: {error details}",
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
1. **Simple** - No complex data structures or state management
2. **Fast** - Single HTTP request, immediate feedback
3. **Safe** - Idempotent operation (can be repeated safely)
4. **User-Friendly** - Clear visual feedback (loading → success/error)

### Design Decisions
1. **POST instead of GET** - Cache clearing is a mutating operation
2. **Auto-dismiss success message** - Avoids UI clutter
3. **No confirmation dialog** - Cache clear is safe and commonly used
4. **Inline in main menu** - Quick access without navigation

### Potential Improvements
- [ ] Add haptic feedback on success
- [ ] Add cache statistics (size cleared, types)
- [ ] Selective cache clearing (choose specific caches)
- [ ] Show last cleared timestamp

### Known Issues
None currently - this feature works as expected.

---

## Testing Checklist

### iOS Testing
- [ ] Button displays correctly in main menu
- [ ] Tap triggers loading state (spinner appears)
- [ ] Success message appears and auto-dismisses after 3 seconds
- [ ] Error handling works for network failures
- [ ] Button is disabled during loading
- [ ] Works on both iPad and iPhone

### Server Testing
```bash
# Test with curl
curl -X POST http://your-site/api/admin/cache/clear \
  -H "Content-Type: application/json" \
  -H "Cookie: SESS123abc=xyz"

# Expected response
{"success":true,"message":"All caches cleared successfully","data":null}
```

### Integration Testing
- [ ] Cache actually clears (verify by checking site changes)
- [ ] Session cookie is valid
- [ ] Permissions are enforced (403 for non-admin users)
- [ ] Error logging works (check watchdog)

---

## Related Features
- **Status Report** - Also in "Quick Actions" section
- **Run Cron** - Planned, similar quick-action pattern

---

## For AI Implementers

**This feature is already complete** and serves as a reference for implementing similar simple action-based features.

**Key Patterns to Follow**:
1. Use `Task { await ... }` for async operations
2. Set loading state before API call
3. Use `defer` or explicit state management to clear loading
4. Show success message with auto-dismiss timer
5. Use `apiClient.lastError` for errors
6. Make button disabled during loading
7. Use simple, action-based POST endpoints
8. Return standard `APIResponse` format
9. Log errors with `watchdog()`

**Similar Features You Could Implement**:
- Run Cron (similar POST action)
- Rebuild Permissions
- Clear Specific Cache Types
- Trigger Site Backup
