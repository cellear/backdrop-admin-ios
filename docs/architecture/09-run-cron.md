# Feature: Run Cron

**Status**: 📋 **PLANNED**

**Category**: System Management

---

## Overview

Manually trigger cron jobs for scheduled tasks like checking for updates, sending emails, processing queues, and running maintenance tasks.

**User Story**: As an admin, I want to manually run cron from my iPad so I can trigger scheduled tasks without waiting for the automatic cron schedule.

---

## UI Components

### Integration
Integrated directly into `MainView` (main menu) under "Quick Actions" section, similar to Clear Cache.

### Visual Design
- **Button** with clock/arrow icon (`clock.arrow.circlepath` SF Symbol)
- **Loading Indicator** (spinner) when cron is running
- **Success Message** (green text) with execution summary
- **Error Message** (red text) if cron fails
- **Last Run Timestamp** - Show when cron last executed

### Implementation Sketch
```swift
Button(action: {
    Task {
        await apiClient.runCron()
        cronMessage = "Cron executed successfully"
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            cronMessage = nil
        }
    }
}) {
    HStack {
        Image(systemName: "clock.arrow.circlepath")
        VStack(alignment: .leading) {
            Text("Run Cron")
            if let lastRun = lastCronRun {
                Text("Last run: \(lastRun)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        if apiClient.isLoading {
            Spacer()
            ProgressView()
        }
    }
}
.disabled(apiClient.isLoading)
```

### States
1. **Idle** - Button enabled, shows last run time
2. **Running** - Spinner visible, button disabled
3. **Success** - Green message with execution details (auto-dismisses)
4. **Error** - Error message (persists)

---

## iOS Client Components

### Data Models

```swift
// Cron execution response
struct CronResponse: Codable {
    let executed: Bool
    let duration: Double        // Execution time in seconds
    let tasksRun: Int          // Number of tasks executed
    let timestamp: Int         // When cron ran
    let summary: String?       // Optional summary message
}
```

### API Method

**Location**: Add to `APIClient.swift`

```swift
func runCron() async throws -> CronResponse {
    let data = try await makeRequest(endpoint: "cron/run", method: "POST")
    let response = try JSONDecoder().decode(APIResponse<CronResponse>.self, from: data)
    guard let cronData = response.data else {
        throw APIError.invalidResponse
    }
    return cronData
}
```

### Request Details
- **Endpoint**: `cron/run`
- **Full URL**: `{siteURL}/api/admin/cron/run`
- **Method**: `POST`
- **Body**: None
- **Headers**: Standard auth headers

### Response Handling
Expects `APIResponse<CronResponse>`:
```json
{
  "success": true,
  "message": "Cron executed successfully",
  "data": {
    "executed": true,
    "duration": 2.5,
    "tasks_run": 15,
    "timestamp": 1701234567,
    "summary": "Processed 15 tasks in 2.5 seconds"
  }
}
```

---

## Server Components (Backdrop)

### Route Definition

```php
$items['api/admin/cron/run'] = array(
  'title' => 'Run Cron',
  'page callback' => 'backdrop_admin_api_run_cron',
  'access arguments' => array('administer site configuration'),
  'type' => MENU_CALLBACK,
);
```

### Callback Function

```php
/**
 * Callback for POST /api/admin/cron/run
 */
function backdrop_admin_api_run_cron() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $start_time = microtime(TRUE);

    // Run cron
    backdrop_cron_run();

    $end_time = microtime(TRUE);
    $duration = round($end_time - $start_time, 2);

    // Get number of tasks from last cron run (if tracked)
    // This is approximate - Backdrop doesn't track this by default
    $tasks_run = 0;

    // You could track this with a custom variable or by hooking into cron
    // For now, just return a success message

    $response = array(
      'success' => TRUE,
      'message' => 'Cron executed successfully',
      'data' => array(
        'executed' => TRUE,
        'duration' => $duration,
        'tasks_run' => $tasks_run,
        'timestamp' => time(),
        'summary' => sprintf('Cron completed in %s seconds', $duration),
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Cron run error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Cron execution failed: ' . $e->getMessage(),
      'data' => NULL,
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**None** - Uses Backdrop's built-in cron system.

### Backdrop API Used
- `backdrop_cron_run()` - Executes all registered cron hooks
- `microtime()` - Measure execution time
- `watchdog()` - Log errors

### What Cron Does
Running cron triggers all modules' `hook_cron()` implementations, which typically:
- Check for module/theme updates
- Send queued emails
- Clean up old data (logs, cache, temporary files)
- Process batch operations
- Aggregate RSS feeds
- Index content for search
- Run scheduled tasks

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager` - For authentication headers
- ✅ `APIClient` - For HTTP request handling
- ✅ `APIClient.makeRequest()` - Core HTTP method
- ✅ `APIResponse<T>` - Standard response wrapper

### From Server:
- ✅ `hook_menu()` - Route registration
- ✅ Standard response format
- ✅ Access control via `access arguments`
- ✅ `backdrop_cron_run()` - Built-in Backdrop function

---

## API Specification

### Endpoint
```
POST /api/admin/cron/run
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
  "message": "Cron executed successfully",
  "data": {
    "executed": true,
    "duration": 2.5,
    "tasks_run": 15,
    "timestamp": 1701234567,
    "summary": "Cron completed in 2.5 seconds"
  }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Cron execution failed: {error details}",
  "data": null
}
```

### HTTP Error Responses
- **401 Unauthorized** - Not logged in
- **403 Forbidden** - Insufficient permissions
- **500 Internal Server Error** - Cron execution error

---

## Implementation Notes

### Why This Works Well
1. **Simple** - Similar to Clear Cache implementation
2. **Fast** - Single button tap
3. **Safe** - Cron is designed to be run repeatedly
4. **Useful** - Common admin task

### Design Decisions
1. **POST instead of GET** - Cron is a mutating operation
2. **Show execution time** - Helps identify performance issues
3. **Auto-dismiss message** - Avoid UI clutter
4. **Track last run** - Helps admins know when cron last executed
5. **No confirmation dialog** - Cron is safe to run

### Timing Considerations
- Cron can take several seconds to execute
- Use longer timeout for this request (30+ seconds)
- Show loading state during execution
- Consider background execution for very long cron jobs

### Potential Improvements
- [ ] Show detailed task breakdown
- [ ] Progress indicator for long-running cron
- [ ] Schedule automatic cron runs
- [ ] View cron execution history
- [ ] Selective cron (run specific modules only)

---

## Testing Checklist

### iOS Testing
- [ ] Button displays correctly in main menu
- [ ] Tap triggers loading state
- [ ] Success message shows execution details
- [ ] Message auto-dismisses after 5 seconds
- [ ] Error handling for timeouts
- [ ] Button disabled during execution

### Server Testing
```bash
# Test with curl
curl -X POST http://your-site/api/admin/cron/run \
  -H "Content-Type: application/json" \
  -H "Cookie: SESS123abc=xyz"

# Expected response
{
  "success": true,
  "message": "Cron executed successfully",
  "data": {
    "executed": true,
    "duration": 2.5,
    ...
  }
}
```

### Integration Testing
- [ ] Cron actually executes (check watchdog logs)
- [ ] Module hooks are called
- [ ] Execution time is accurate
- [ ] Permissions are enforced
- [ ] Error logging works

---

## Related Features
- **Clear Cache** - Similar quick-action pattern
- **Status Report** - May show cron status

---

## For AI Implementers

**This feature follows the Clear Cache pattern** - use it as a reference.

**Key Implementation Steps**:

### iOS Side:
1. Add `CronResponse` model to `APIClient.swift`
2. Add `runCron()` method to `APIClient.swift`
3. Add button to `MainView` in "Quick Actions" section
4. Track last run timestamp in `@State`
5. Show execution summary in success message

### Server Side:
1. Add route in `backdrop_admin_api_menu()`
2. Implement `backdrop_admin_api_run_cron()` callback
3. Call `backdrop_cron_run()`
4. Measure execution time
5. Return standard response format

### Considerations:
- Use longer timeout (30-60 seconds) for cron requests
- Consider showing estimated completion time
- Handle timeout errors gracefully
- Log successful executions to watchdog

**Similar Pattern**: This is nearly identical to Clear Cache, just calling `backdrop_cron_run()` instead of `backdrop_flush_all_caches()`.
