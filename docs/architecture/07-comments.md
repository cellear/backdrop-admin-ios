# Feature: Comment Moderation

**Status**: 📋 **PLANNED**

**Category**: Community Management

---

## Overview

Quick moderation interface for managing comments. View pending comments, approve/reject with swipe actions, mark as spam, and respond inline.

**User Story**: As an admin, I want to moderate comments from my iPad so I can quickly approve good comments and remove spam while mobile.

---

## UI Components

### Main View
`CommentModerationView` - List of comments with filter tabs and swipe actions.

### Visual Design
- **Tab Bar** - Pending, Published, Spam, All
- **Comment Cards** - Author, content preview, post title, timestamp
- **Swipe Actions** - Approve, Reject, Spam, Delete
- **Filter Button** - Filter by content type or date
- **Empty State** - "No pending comments"
- **Bulk Actions** - Select mode for bulk operations

### View Hierarchy
```
NavigationView
└── VStack
    ├── Picker (Tab selector: Pending, Published, Spam)
    └── List
        ├── CommentCard (repeating)
        │   ├── Swipe Right: Approve
        │   └── Swipe Left: Reject/Delete
        └── LoadMoreButton
```

### Comment Card Component

**Visual Elements**:
- **Author Info** - Name, email (masked), IP address
- **Comment Text** - First 150 chars with "Read more"
- **Post Link** - "On: [Post Title]"
- **Timestamp** - Relative time (2 hours ago)
- **Status Badge** - Pending/Published/Spam
- **Action Buttons** - Approve, Reject, Spam, View Post

**Swipe Actions**:
- **Swipe Right** → Approve (green)
- **Swipe Left** → Reject/Delete (red)
- **Swipe Left More** → Mark as Spam (orange)

---

## iOS Client Components

### Data Models

```swift
// Comment list response
struct CommentListData: Codable {
    let items: [Comment]
    let total: Int
    let pending: Int      // Count of pending
    let spam: Int         // Count of spam
    let page: Int
    let limit: Int
}

// Individual comment
struct Comment: Codable, Identifiable {
    let id: Int             // Comment ID
    let nid: Int            // Node ID
    let nodeTitle: String   // Post title
    let uid: Int            // Author user ID (0 = anonymous)
    let name: String        // Author name
    let mail: String?       // Author email (may be hidden)
    let homepage: String?   // Author URL
    let hostname: String    // IP address
    let created: Int        // Timestamp
    let subject: String     // Comment subject
    let comment: String     // Comment body
    let status: Int         // 1 = published, 0 = unpublished
    let thread: String?     // Threading info
    let isSpam: Bool        // Marked as spam

    enum CodingKeys: String, CodingKey {
        case id = "cid"
        case nid
        case nodeTitle = "node_title"
        case uid, name, mail, homepage, hostname, created
        case subject, comment, status, thread
        case isSpam = "is_spam"
    }
}

// Action request
enum CommentAction: String, Codable {
    case approve, reject, spam, delete
}

struct CommentActionRequest: Codable {
    let action: String
    let ids: [Int]
}
```

### View Model

```swift
class CommentModerationViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab: String = "pending"  // pending, published, spam, all
    @Published var pendingCount: Int = 0
    @Published var spamCount: Int = 0

    private let apiClient: APIClient

    func loadComments() async {
        // Load comments for selected tab
    }

    func approveComment(id: Int) async throws {
        // Approve single comment
    }

    func rejectComment(id: Int) async throws {
        // Unpublish comment
    }

    func markAsSpam(id: Int) async throws {
        // Mark as spam
    }

    func deleteComment(id: Int) async throws {
        // Delete permanently
    }

    func bulkAction(action: CommentAction, ids: [Int]) async throws {
        // Perform bulk action
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get comments
func getComments(
    status: String = "pending",
    page: Int = 1,
    limit: Int = 20
) async throws -> CommentListData {
    let endpoint = "comments/list?status=\(status)&page=\(page)&limit=\(limit)"
    let data = try await makeRequest(endpoint: endpoint, method: "GET")
    let response = try JSONDecoder().decode(APIResponse<CommentListData>.self, from: data)
    guard let commentData = response.data else {
        throw APIError.invalidResponse
    }
    return commentData
}

// Moderate comment
func moderateComment(id: Int, action: CommentAction) async throws {
    let request = CommentActionRequest(action: action.rawValue, ids: [id])
    let encoder = JSONEncoder()
    let body = try encoder.encode(request)
    _ = try await makeRequest(endpoint: "comments/moderate", method: "POST", body: body)
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// List comments
$items['api/admin/comments/list'] = array(
  'title' => 'Comment List',
  'page callback' => 'backdrop_admin_api_comment_list',
  'access arguments' => array('administer comments'),
  'type' => MENU_CALLBACK,
);

// Moderate comments
$items['api/admin/comments/moderate'] = array(
  'title' => 'Moderate Comments',
  'page callback' => 'backdrop_admin_api_comment_moderate',
  'access arguments' => array('administer comments'),
  'type' => MENU_CALLBACK,
);
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/comments/list
 */
function backdrop_admin_api_comment_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    if (!module_exists('comment')) {
      throw new Exception('Comment module is not enabled');
    }

    $status = isset($_GET['status']) ? $_GET['status'] : 'pending';
    $page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 20;
    $offset = ($page - 1) * $limit;

    // Build query
    $query = db_select('comment', 'c')
      ->fields('c')
      ->orderBy('created', 'DESC')
      ->range($offset, $limit);

    // Add status filter
    if ($status === 'pending') {
      $query->condition('status', 0);
    } elseif ($status === 'published') {
      $query->condition('status', 1);
    } elseif ($status === 'spam') {
      // Assume spam is tracked in a custom field or table
      // This would need custom implementation
    }

    $results = $query->execute();

    // Get counts
    $pending_count = db_query("SELECT COUNT(*) FROM {comment} WHERE status = 0")->fetchField();
    $spam_count = 0;  // Would need spam tracking implementation
    $total = db_query("SELECT COUNT(*) FROM {comment}")->fetchField();

    // Format results
    $items = array();
    foreach ($results as $comment) {
      // Load node for title
      $node = node_load($comment->nid);

      $items[] = array(
        'cid' => (int)$comment->cid,
        'nid' => (int)$comment->nid,
        'node_title' => $node ? $node->title : 'Unknown',
        'uid' => (int)$comment->uid,
        'name' => $comment->name,
        'mail' => $comment->mail,
        'homepage' => $comment->homepage,
        'hostname' => $comment->hostname,
        'created' => (int)$comment->created,
        'subject' => $comment->subject,
        'comment' => substr(strip_tags($comment->comment_body[LANGUAGE_NONE][0]['value']), 0, 500),
        'status' => (int)$comment->status,
        'thread' => $comment->thread,
        'is_spam' => FALSE,  // Would need spam detection
      );
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'items' => $items,
        'total' => (int)$total,
        'pending' => (int)$pending_count,
        'spam' => (int)$spam_count,
        'page' => $page,
        'limit' => $limit,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Comment list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load comments: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/comments/moderate
 */
function backdrop_admin_api_comment_moderate() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $input = file_get_contents('php://input');
    $data = backdrop_json_decode($input);

    if (!$data || empty($data['action']) || empty($data['ids'])) {
      throw new Exception('Invalid moderation request');
    }

    $action = $data['action'];
    $ids = $data['ids'];

    foreach ($ids as $cid) {
      $comment = comment_load($cid);
      if (!$comment) {
        continue;
      }

      switch ($action) {
        case 'approve':
          $comment->status = COMMENT_PUBLISHED;
          comment_save($comment);
          break;

        case 'reject':
          $comment->status = COMMENT_NOT_PUBLISHED;
          comment_save($comment);
          break;

        case 'spam':
          // Mark as spam (would need custom implementation)
          $comment->status = COMMENT_NOT_PUBLISHED;
          comment_save($comment);
          // Could add to spam table or set custom field
          break;

        case 'delete':
          comment_delete($cid);
          break;
      }
    }

    $response = array(
      'success' => TRUE,
      'message' => ucfirst($action) . ' action completed successfully',
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Comment moderate error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Moderation failed: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**Existing tables**:
- `comment` - Comment storage
- `node` - For post titles

### Backdrop API Used
- `comment_load()` - Load comment object
- `comment_save()` - Save comment
- `comment_delete()` - Delete comment
- `node_load()` - Get post title
- Constants: `COMMENT_PUBLISHED`, `COMMENT_NOT_PUBLISHED`

---

## API Specification

### List Comments
```
GET /api/admin/comments/list?status=pending&page=1&limit=20
```

**Response**:
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "cid": 45,
        "nid": 12,
        "node_title": "My Blog Post",
        "uid": 0,
        "name": "Anonymous",
        "mail": "user@example.com",
        "homepage": null,
        "hostname": "192.168.1.100",
        "created": 1701234567,
        "subject": "Great post!",
        "comment": "This is a great article, thanks for sharing...",
        "status": 0,
        "thread": "01/",
        "is_spam": false
      }
    ],
    "total": 150,
    "pending": 12,
    "spam": 3,
    "page": 1,
    "limit": 20
  }
}
```

### Moderate Comments
```
POST /api/admin/comments/moderate
```

**Request**:
```json
{
  "action": "approve",
  "ids": [45, 46, 47]
}
```

---

## For AI Implementers

### iOS Tasks:
1. Create `CommentModerationView.swift`
2. Implement tab switching
3. Add swipe actions
4. Create comment card component
5. Add bulk selection mode
6. Show counts in tab badges

### Server Tasks:
1. Add routes
2. Implement list/moderate callbacks
3. Handle comment loading
4. Implement spam detection (optional)
5. Test moderation actions
