# Feature: Content List

**Status**: 📋 **PLANNED**

**Category**: Content Management

---

## Overview

Displays a list of content (nodes) with search, filtering, and sorting capabilities. Provides quick access to view and edit content from the iPad interface.

**User Story**: As an admin, I want to browse and search my site's content on my iPad so I can quickly find and access content for editing or review.

---

## UI Components

### Main View
`ContentListView` - Full-screen view with search bar, filters, and scrollable content list.

### Visual Design
- **Navigation Bar** with "Content" title and filter button
- **Search Bar** - Real-time search with debouncing
- **Filter Panel** - Sheet or dropdown for filtering options
- **Content List** - Card-based or row-based list items
- **Pagination Controls** - Load more / infinite scroll
- **Empty State** - "No content found" with create button
- **Loading State** - Skeleton loading or spinner
- **Pull-to-Refresh** - Refresh gesture

### View Hierarchy
```
NavigationView
└── VStack
    ├── SearchBar (top)
    ├── FilterChips (active filters)
    └── List/ScrollView
        ├── ContentRow (repeating)
        ├── LoadingRow (if loading more)
        └── LoadMoreButton (if more available)
```

### Content Row Component

**Visual Elements**:
- **Title** - Bold headline, truncated to 2 lines
- **Type Icon** - SF Symbol or custom icon for content type
- **Status Badge** - Published/Draft/Scheduled
- **Metadata** - Author, date, comment count
- **Thumbnail** - Small image preview (if available)
- **Swipe Actions** - Edit, Delete, View

**Example Layout**:
```
┌─────────────────────────────────────┐
│ 📄 Welcome to My Site             │
│    Published • 2 days ago          │
│    by admin • 3 comments           │
└─────────────────────────────────────┘
```

### Filter Options
- **Content Type** - Page, Post, Article, etc.
- **Status** - All, Published, Unpublished, Scheduled
- **Author** - All, Current User, Specific User
- **Date Range** - Last week, month, year, custom
- **Sort** - Recent first, Oldest first, Title A-Z

---

## iOS Client Components

### Data Models

```swift
// List response
struct ContentListData: Codable {
    let items: [ContentItem]
    let total: Int
    let page: Int
    let limit: Int
    let pages: Int
}

// Individual content item
struct ContentItem: Codable, Identifiable {
    let id: Int             // Node ID
    let title: String
    let type: String        // Content type machine name
    let typeLabel: String   // Content type display name
    let status: Int         // 1 = published, 0 = unpublished
    let created: Int        // Unix timestamp
    let changed: Int        // Unix timestamp
    let author: String      // Author name
    let authorUid: Int      // Author user ID
    let commentCount: Int?  // Number of comments
    let thumbnail: String?  // URL to thumbnail image
    let excerpt: String?    // Brief excerpt/summary

    enum CodingKeys: String, CodingKey {
        case id = "nid"
        case title
        case type
        case typeLabel = "type_label"
        case status
        case created
        case changed
        case author
        case authorUid = "author_uid"
        case commentCount = "comment_count"
        case thumbnail
        case excerpt
    }
}

// Filter state
struct ContentFilters {
    var searchText: String = ""
    var contentType: String? = nil
    var status: String? = nil  // "published", "unpublished", "all"
    var author: String? = nil
    var sortBy: String = "recent"  // "recent", "oldest", "title"
}
```

### View Model

```swift
class ContentListViewModel: ObservableObject {
    @Published var items: [ContentItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var filters = ContentFilters()
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMore = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadContent() async {
        // Load first page
    }

    func loadMore() async {
        // Load next page
    }

    func refresh() async {
        // Reset and reload
    }

    func applyFilters() async {
        // Reload with new filters
    }
}
```

### API Method

**Location**: Add to `APIClient.swift`

```swift
func getContentList(
    page: Int = 1,
    limit: Int = 20,
    search: String? = nil,
    type: String? = nil,
    status: String? = nil,
    sortBy: String = "recent"
) async throws -> ContentListData {
    var queryParams: [String] = []
    queryParams.append("page=\(page)")
    queryParams.append("limit=\(limit)")
    if let search = search, !search.isEmpty {
        queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    if let type = type {
        queryParams.append("type=\(type)")
    }
    if let status = status {
        queryParams.append("status=\(status)")
    }
    queryParams.append("sort=\(sortBy)")

    let queryString = queryParams.joined(separator: "&")
    let endpoint = "content/list?\(queryString)"

    let data = try await makeRequest(endpoint: endpoint, method: "GET")
    let response = try JSONDecoder().decode(APIResponse<ContentListData>.self, from: data)
    guard let contentData = response.data else {
        throw APIError.invalidResponse
    }
    return contentData
}
```

### Request Details
- **Endpoint**: `content/list`
- **Full URL**: `{siteURL}/api/admin/content/list?page=1&limit=20&search=...&type=...&status=...&sort=...`
- **Method**: `GET`
- **Query Parameters**:
  - `page` (int, default: 1)
  - `limit` (int, default: 20, max: 100)
  - `search` (string, optional)
  - `type` (string, optional) - Content type machine name
  - `status` (string, optional) - "published", "unpublished", "all"
  - `sort` (string, default: "recent") - "recent", "oldest", "title"
- **Headers**: Standard auth headers

### Response Handling
Success → Update view model with items
Error → Display error message
Empty → Show empty state with create button

---

## Server Components (Backdrop)

### Route Definition

```php
$items['api/admin/content/list'] = array(
  'title' => 'Content List',
  'page callback' => 'backdrop_admin_api_content_list',
  'access arguments' => array('access content overview'),
  'type' => MENU_CALLBACK,
);
```

### Callback Function

```php
/**
 * Callback for GET /api/admin/content/list
 */
function backdrop_admin_api_content_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Get query parameters
    $page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 20;
    $search = isset($_GET['search']) ? $_GET['search'] : NULL;
    $type = isset($_GET['type']) ? $_GET['type'] : NULL;
    $status = isset($_GET['status']) ? $_GET['status'] : NULL;
    $sort = isset($_GET['sort']) ? $_GET['sort'] : 'recent';

    $offset = ($page - 1) * $limit;

    // Build query
    $query = db_select('node', 'n')
      ->fields('n', array('nid', 'title', 'type', 'status', 'created', 'changed', 'uid'))
      ->range($offset, $limit);

    // Add search condition
    if ($search) {
      $query->condition('title', '%' . db_like($search) . '%', 'LIKE');
    }

    // Add type filter
    if ($type) {
      $query->condition('type', $type);
    }

    // Add status filter
    if ($status === 'published') {
      $query->condition('status', 1);
    } elseif ($status === 'unpublished') {
      $query->condition('status', 0);
    }

    // Add sorting
    switch ($sort) {
      case 'oldest':
        $query->orderBy('created', 'ASC');
        break;
      case 'title':
        $query->orderBy('title', 'ASC');
        break;
      case 'recent':
      default:
        $query->orderBy('created', 'DESC');
        break;
    }

    // Execute query
    $results = $query->execute();

    // Get total count for pagination
    $count_query = db_select('node', 'n')
      ->fields('n', array('nid'));
    if ($search) {
      $count_query->condition('title', '%' . db_like($search) . '%', 'LIKE');
    }
    if ($type) {
      $count_query->condition('type', $type);
    }
    if ($status === 'published') {
      $count_query->condition('status', 1);
    } elseif ($status === 'unpublished') {
      $count_query->condition('status', 0);
    }
    $total = $count_query->countQuery()->execute()->fetchField();
    $total_pages = ceil($total / $limit);

    // Format results
    $items = array();
    foreach ($results as $row) {
      // Load full node for additional data
      $node = node_load($row->nid);

      // Get author name
      $author = user_load($node->uid);

      // Get content type label
      $type_info = node_type_get_type($node->type);

      // Get comment count (if comments module enabled)
      $comment_count = 0;
      if (module_exists('comment')) {
        $comment_count = db_query(
          "SELECT COUNT(*) FROM {comment} WHERE nid = :nid AND status = 1",
          array(':nid' => $node->nid)
        )->fetchField();
      }

      // Get thumbnail (check for image field)
      $thumbnail = NULL;
      if (isset($node->field_image) && !empty($node->field_image)) {
        $image = field_get_items('node', $node, 'field_image');
        if ($image && isset($image[0]['uri'])) {
          $thumbnail = file_create_url($image[0]['uri']);
        }
      }

      // Get excerpt (first 150 chars of body)
      $excerpt = NULL;
      if (isset($node->body) && !empty($node->body)) {
        $body = field_get_items('node', $node, 'body');
        if ($body && isset($body[0]['value'])) {
          $excerpt = substr(strip_tags($body[0]['value']), 0, 150);
        }
      }

      $items[] = array(
        'nid' => (int)$node->nid,
        'title' => $node->title,
        'type' => $node->type,
        'type_label' => $type_info->name,
        'status' => (int)$node->status,
        'created' => (int)$node->created,
        'changed' => (int)$node->changed,
        'author' => $author->name,
        'author_uid' => (int)$author->uid,
        'comment_count' => (int)$comment_count,
        'thumbnail' => $thumbnail,
        'excerpt' => $excerpt,
      );
    }

    $response = array(
      'success' => TRUE,
      'message' => NULL,
      'data' => array(
        'items' => $items,
        'total' => (int)$total,
        'page' => $page,
        'limit' => $limit,
        'pages' => $total_pages,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Content list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load content: ' . $e->getMessage(),
      'data' => NULL,
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**Existing tables**:
- `node` - Main content table
- `comment` - Comment tracking (optional)
- `users` - User data
- `file_managed` - File/image data (if thumbnails)

### Backdrop API Used
- `db_select()` - Database query builder
- `db_like()` - Escape search strings
- `node_load()` - Load full node object
- `user_load()` - Load user object
- `node_type_get_type()` - Get content type info
- `field_get_items()` - Get field values
- `file_create_url()` - Generate public URL for files

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager` - For authentication
- ✅ `APIClient` - For HTTP requests
- ✅ `APIResponse<T>` - Standard response wrapper
- ⚠️ Need to add search debouncing utility
- ⚠️ Need to add pagination helper

### From Server:
- ✅ `hook_menu()` - Route registration
- ✅ Standard response format
- ✅ Database query API
- ✅ Node loading API

---

## API Specification

### Endpoint
```
GET /api/admin/content/list
```

### Query Parameters
- `page` (integer, default: 1) - Page number
- `limit` (integer, default: 20, max: 100) - Items per page
- `search` (string, optional) - Search query for titles
- `type` (string, optional) - Content type machine name filter
- `status` (string, optional) - "published", "unpublished", or "all"
- `sort` (string, default: "recent") - "recent", "oldest", "title"

### Request Headers
```
Content-Type: application/json
Cookie: SESS{hash}={session_id}
```

### Success Response (200 OK)
```json
{
  "success": true,
  "message": null,
  "data": {
    "items": [
      {
        "nid": 1,
        "title": "Welcome to My Site",
        "type": "page",
        "type_label": "Basic page",
        "status": 1,
        "created": 1701234567,
        "changed": 1701234890,
        "author": "admin",
        "author_uid": 1,
        "comment_count": 3,
        "thumbnail": "http://example.com/sites/default/files/image.jpg",
        "excerpt": "Welcome to my new Backdrop site. This is a sample page..."
      }
    ],
    "total": 150,
    "page": 1,
    "limit": 20,
    "pages": 8
  }
}
```

---

## Implementation Notes

### Design Decisions
1. **Pagination required** - Large sites may have thousands of nodes
2. **Search on title only** - Body search would be too slow without full-text indexing
3. **Thumbnail optional** - Not all content types have images
4. **Load full node** - Needed for additional field data
5. **Debounce search** - Avoid API calls on every keystroke

### Performance Considerations
- Index `node.title` for search performance
- Limit page size to prevent timeout
- Consider caching popular queries
- Lazy load thumbnails in iOS

### Potential Improvements
- [ ] Bulk operations (publish, delete)
- [ ] Saved filters/searches
- [ ] Full-text search
- [ ] Additional field filtering
- [ ] Sorting by multiple fields

---

## For AI Implementers

**Key Implementation Tasks**:

### iOS Side:
1. Create `ContentListView.swift`
2. Create `ContentListViewModel.swift`
3. Create `ContentRow.swift` component
4. Add search debouncing (300ms delay)
5. Implement infinite scroll or "Load More" button
6. Add pull-to-refresh
7. Create filter sheet UI
8. Add method to `APIClient.swift`
9. Add navigation link in `MainView`

### Server Side:
1. Add route in `backdrop_admin_api_menu()`
2. Implement `backdrop_admin_api_content_list()` callback
3. Test with various content types
4. Optimize queries for performance
5. Handle edge cases (no content, search with no results)

### Testing:
- Test with 0, 1, 20, 100+ content items
- Test search functionality
- Test filtering by type and status
- Test pagination
- Test sorting options
- Verify performance with large datasets
