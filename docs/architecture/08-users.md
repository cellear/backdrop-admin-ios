# Feature: User Management

**Status**: 📋 **PLANNED**

**Category**: Community Management

---

## Overview

Browse users, view user details, block/unblock accounts, and manage basic user settings. Complex user operations fall back to web interface.

**User Story**: As an admin, I want to manage user accounts from my iPad so I can quickly block spam accounts or review user activity.

---

## UI Components

### Main View
`UserManagementView` - Searchable list of users with filter options.

### Visual Design
- **Search Bar** - Search by username or email
- **Filter Chips** - Active, Blocked, All, Admins
- **User List** - Avatar, username, email, status, last login
- **User Detail Sheet** - Full user info with actions
- **Swipe Actions** - Block/Unblock, View Profile
- **Empty State** - "No users found"

### View Hierarchy
```
NavigationView
└── VStack
    ├── SearchBar
    ├── FilterChips
    └── List
        ├── UserRow (repeating)
        └── LoadMoreButton
```

### User Row Component

**Visual Elements**:
- **Avatar** - Gravatar or initials
- **Username** - Bold text
- **Email** - Secondary text (masked if privacy)
- **Status Badge** - Active/Blocked/Admin
- **Last Login** - Relative time
- **Registration Date** - Small text

**Detail Sheet**:
- User info (name, email, roles, created, last login)
- Activity summary (content count, comment count)
- Actions (Block, Unblock, Reset Password, View on Web)

---

## iOS Client Components

### Data Models

```swift
// User list response
struct UserListData: Codable {
    let items: [User]
    let total: Int
    let page: Int
    let limit: Int
}

// Individual user
struct User: Codable, Identifiable {
    let id: Int             // User ID
    let name: String        // Username
    let mail: String        // Email
    let status: Int         // 1 = active, 0 = blocked
    let created: Int        // Registration timestamp
    let access: Int         // Last login timestamp
    let login: Int          // Current login timestamp
    let roles: [String]     // Role names
    let picture: String?    // Profile picture URL

    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case name, mail, status, created, access, login, roles, picture
    }

    var isAdmin: Bool {
        roles.contains("administrator")
    }

    var isBlocked: Bool {
        status == 0
    }
}

// User details (extended info)
struct UserDetail: Codable {
    let uid: Int
    let name: String
    let mail: String
    let status: Int
    let created: Int
    let access: Int
    let login: Int
    let roles: [String]
    let picture: String?
    let contentCount: Int   // Number of nodes created
    let commentCount: Int   // Number of comments

    enum CodingKeys: String, CodingKey {
        case uid, name, mail, status, created, access, login, roles, picture
        case contentCount = "content_count"
        case commentCount = "comment_count"
    }
}

// Action request
struct UserActionRequest: Codable {
    let action: String      // "block", "unblock", "reset_password"
    let uid: Int
}
```

### View Model

```swift
class UserManagementViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var filterStatus: String = "all"  // all, active, blocked, admin

    private let apiClient: APIClient

    func loadUsers() async {
        // Load users with filters
    }

    func getUserDetail(id: Int) async throws -> UserDetail {
        // Get detailed user info
    }

    func blockUser(id: Int) async throws {
        // Block user account
    }

    func unblockUser(id: Int) async throws {
        // Unblock user account
    }

    func resetPassword(id: Int) async throws {
        // Trigger password reset email
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get users
func getUsers(
    page: Int = 1,
    limit: Int = 20,
    search: String? = nil,
    status: String = "all"
) async throws -> UserListData {
    var queryParams: [String] = []
    queryParams.append("page=\(page)")
    queryParams.append("limit=\(limit)")
    if let search = search, !search.isEmpty {
        queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    queryParams.append("status=\(status)")

    let queryString = queryParams.joined(separator: "&")
    let endpoint = "users/list?\(queryString)"

    let data = try await makeRequest(endpoint: endpoint, method: "GET")
    let response = try JSONDecoder().decode(APIResponse<UserListData>.self, from: data)
    guard let userData = response.data else {
        throw APIError.invalidResponse
    }
    return userData
}

// Get user detail
func getUserDetail(id: Int) async throws -> UserDetail {
    let data = try await makeRequest(endpoint: "users/\(id)", method: "GET")
    let response = try JSONDecoder().decode(APIResponse<UserDetail>.self, from: data)
    guard let user = response.data else {
        throw APIError.invalidResponse
    }
    return user
}

// User action (block, unblock, reset password)
func userAction(id: Int, action: String) async throws {
    let request = UserActionRequest(action: action, uid: id)
    let encoder = JSONEncoder()
    let body = try encoder.encode(request)
    _ = try await makeRequest(endpoint: "users/action", method: "POST", body: body)
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// List users
$items['api/admin/users/list'] = array(
  'title' => 'User List',
  'page callback' => 'backdrop_admin_api_user_list',
  'access arguments' => array('administer users'),
  'type' => MENU_CALLBACK,
);

// Get user detail
$items['api/admin/users/%'] = array(
  'title' => 'User Detail',
  'page callback' => 'backdrop_admin_api_user_detail',
  'page arguments' => array(3),
  'access arguments' => array('administer users'),
  'type' => MENU_CALLBACK,
);

// User action
$items['api/admin/users/action'] = array(
  'title' => 'User Action',
  'page callback' => 'backdrop_admin_api_user_action',
  'access arguments' => array('administer users'),
  'type' => MENU_CALLBACK,
);
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/users/list
 */
function backdrop_admin_api_user_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 20;
    $search = isset($_GET['search']) ? $_GET['search'] : NULL;
    $status = isset($_GET['status']) ? $_GET['status'] : 'all';

    $offset = ($page - 1) * $limit;

    // Build query
    $query = db_select('users', 'u')
      ->fields('u', array('uid', 'name', 'mail', 'status', 'created', 'access', 'login'))
      ->condition('uid', 0, '>')  // Exclude anonymous
      ->orderBy('created', 'DESC')
      ->range($offset, $limit);

    // Search filter
    if ($search) {
      $or = db_or()
        ->condition('name', '%' . db_like($search) . '%', 'LIKE')
        ->condition('mail', '%' . db_like($search) . '%', 'LIKE');
      $query->condition($or);
    }

    // Status filter
    if ($status === 'active') {
      $query->condition('status', 1);
    } elseif ($status === 'blocked') {
      $query->condition('status', 0);
    }

    $results = $query->execute();

    // Get total
    $count_query = db_select('users', 'u')
      ->condition('uid', 0, '>');
    if ($search) {
      $or = db_or()
        ->condition('name', '%' . db_like($search) . '%', 'LIKE')
        ->condition('mail', '%' . db_like($search) . '%', 'LIKE');
      $count_query->condition($or);
    }
    if ($status === 'active') {
      $count_query->condition('status', 1);
    } elseif ($status === 'blocked') {
      $count_query->condition('status', 0);
    }
    $total = $count_query->countQuery()->execute()->fetchField();

    // Format results
    $items = array();
    foreach ($results as $row) {
      $user = user_load($row->uid);

      // Get role names
      $role_names = array();
      foreach ($user->roles as $rid => $role) {
        $role_names[] = $role;
      }

      // Get profile picture if available
      $picture = NULL;
      if (isset($user->picture) && !empty($user->picture)) {
        $file = file_load($user->picture);
        if ($file) {
          $picture = file_create_url($file->uri);
        }
      }

      $items[] = array(
        'uid' => (int)$user->uid,
        'name' => $user->name,
        'mail' => $user->mail,
        'status' => (int)$user->status,
        'created' => (int)$user->created,
        'access' => (int)$user->access,
        'login' => (int)$user->login,
        'roles' => $role_names,
        'picture' => $picture,
      );
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'items' => $items,
        'total' => (int)$total,
        'page' => $page,
        'limit' => $limit,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'User list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load users: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for GET /api/admin/users/{uid}
 */
function backdrop_admin_api_user_detail($uid) {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $user = user_load($uid);
    if (!$user) {
      throw new Exception('User not found');
    }

    // Get role names
    $role_names = array_values($user->roles);

    // Get picture
    $picture = NULL;
    if (isset($user->picture) && !empty($user->picture)) {
      $file = file_load($user->picture);
      if ($file) {
        $picture = file_create_url($file->uri);
      }
    }

    // Get content count
    $content_count = db_query(
      "SELECT COUNT(*) FROM {node} WHERE uid = :uid",
      array(':uid' => $uid)
    )->fetchField();

    // Get comment count
    $comment_count = 0;
    if (module_exists('comment')) {
      $comment_count = db_query(
        "SELECT COUNT(*) FROM {comment} WHERE uid = :uid",
        array(':uid' => $uid)
      )->fetchField();
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'uid' => (int)$user->uid,
        'name' => $user->name,
        'mail' => $user->mail,
        'status' => (int)$user->status,
        'created' => (int)$user->created,
        'access' => (int)$user->access,
        'login' => (int)$user->login,
        'roles' => $role_names,
        'picture' => $picture,
        'content_count' => (int)$content_count,
        'comment_count' => (int)$comment_count,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'User detail error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load user: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/users/action
 */
function backdrop_admin_api_user_action() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $input = file_get_contents('php://input');
    $data = backdrop_json_decode($input);

    if (!$data || empty($data['action']) || !isset($data['uid'])) {
      throw new Exception('Invalid action request');
    }

    $uid = $data['uid'];
    $action = $data['action'];

    // Don't allow blocking UID 1
    if ($uid == 1 && $action === 'block') {
      throw new Exception('Cannot block the root user');
    }

    $user = user_load($uid);
    if (!$user) {
      throw new Exception('User not found');
    }

    switch ($action) {
      case 'block':
        user_save($user, array('status' => 0));
        $message = 'User blocked successfully';
        break;

      case 'unblock':
        user_save($user, array('status' => 1));
        $message = 'User unblocked successfully';
        break;

      case 'reset_password':
        // Trigger password reset
        $mail = _user_mail_notify('password_reset', $user);
        if ($mail) {
          $message = 'Password reset email sent';
        } else {
          throw new Exception('Failed to send password reset email');
        }
        break;

      default:
        throw new Exception('Unknown action: ' . $action);
    }

    $response = array(
      'success' => TRUE,
      'message' => $message,
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'User action error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Action failed: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**Existing tables**:
- `users` - User accounts
- `users_roles` - User role assignments
- `node` - For content count
- `comment` - For comment count

### Backdrop API Used
- `user_load()` - Load user object
- `user_save()` - Save user
- `_user_mail_notify()` - Send email notifications
- `file_load()` - Load profile picture

---

## API Specification

### List Users
```
GET /api/admin/users/list?page=1&limit=20&search=&status=all
```

**Response**: (See UserListData model above)

### Get User Detail
```
GET /api/admin/users/123
```

**Response**: (See UserDetail model above)

### User Action
```
POST /api/admin/users/action
```

**Request**:
```json
{
  "action": "block",
  "uid": 123
}
```

---

## For AI Implementers

### iOS Tasks:
1. Create `UserManagementView.swift`
2. Create `UserDetailSheet.swift`
3. Add search and filtering
4. Implement swipe actions
5. Add confirmation dialogs for destructive actions
6. Handle avatar display (Gravatar or initials)

### Server Tasks:
1. Add routes
2. Implement list/detail/action callbacks
3. Add role filtering support
4. Protect UID 1 from blocking
5. Test password reset emails
