# Feature: File Management

**Status**: 📋 **PLANNED**

**Category**: Asset Management

---

## Overview

Browse, upload, and manage files and images on the Backdrop site. Native interface for viewing files with filtering, search, and camera upload integration.

**User Story**: As an admin, I want to manage files and upload photos from my iPad camera so I can quickly add images to my site while mobile.

---

## UI Components

### Main View
`FileManagementView` - List of files with search, filter, and upload capabilities.

### Visual Design
- **Navigation Bar** with "Files" title and upload button
- **Search Bar** - Search by filename
- **Filter Panel** - Filter by type (image, document, video, audio)
- **File Grid** - Thumbnail grid for images, icons for other files
- **File Details** - Sheet showing file info and actions
- **Upload Button** - Camera or photo library
- **Empty State** - "No files" with upload button

### View Hierarchy
```
NavigationView
└── VStack
    ├── SearchBar
    ├── FilterChips (Images, Documents, All)
    └── Grid/List
        ├── FileCard (repeating)
        └── LoadMoreButton
```

### File Card Component

**For Images**:
- Thumbnail preview
- Filename (truncated)
- File size
- Upload date
- Usage count (how many nodes use it)

**For Other Files**:
- File type icon (PDF, ZIP, etc.)
- Filename
- File size
- Upload date
- Mimetype label

**Actions** (swipe or tap):
- View/Download
- Copy URL
- Delete (with confirmation)
- View usage (where file is used)

---

## iOS Client Components

### Data Models

```swift
// List response
struct FileListData: Codable {
    let items: [FileItem]
    let total: Int
    let page: Int
    let limit: Int
}

// Individual file
struct FileItem: Codable, Identifiable {
    let id: Int             // File ID
    let filename: String
    let uri: String         // Internal URI (public://filename.jpg)
    let url: String         // Public URL
    let filemime: String    // MIME type
    let filesize: Int       // Size in bytes
    let timestamp: Int      // Upload timestamp
    let uid: Int            // Uploader user ID
    let username: String    // Uploader name
    let usageCount: Int?    // How many times file is used

    enum CodingKeys: String, CodingKey {
        case id = "fid"
        case filename, uri, url, filemime, filesize, timestamp, uid, username
        case usageCount = "usage_count"
    }

    // Helper computed properties
    var isImage: Bool {
        filemime.starts(with: "image/")
    }

    var filesizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(filesize), countStyle: .file)
    }

    var typeLabel: String {
        if filemime.starts(with: "image/") { return "Image" }
        if filemime.starts(with: "video/") { return "Video" }
        if filemime.starts(with: "audio/") { return "Audio" }
        if filemime == "application/pdf" { return "PDF" }
        if filemime.contains("zip") { return "Archive" }
        return "File"
    }
}

// Upload request
struct FileUploadRequest: Codable {
    let filename: String
    let data: String        // Base64 encoded
}

// Upload response
struct FileUploadResponse: Codable {
    let fid: Int
    let filename: String
    let url: String
    let uri: String
}
```

### View Model

```swift
class FileManagementViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var filterType: String = "all"  // all, image, document, video, audio

    private let apiClient: APIClient

    func loadFiles() async {
        // Load files with filters
    }

    func uploadFile(filename: String, data: Data) async throws -> FileUploadResponse {
        // Upload file
    }

    func deleteFile(id: Int) async throws {
        // Delete file
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get file list
func getFiles(
    page: Int = 1,
    limit: Int = 50,
    search: String? = nil,
    type: String? = nil
) async throws -> FileListData {
    var queryParams: [String] = []
    queryParams.append("page=\(page)")
    queryParams.append("limit=\(limit)")
    if let search = search, !search.isEmpty {
        queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    if let type = type, type != "all" {
        queryParams.append("type=\(type)")
    }

    let queryString = queryParams.joined(separator: "&")
    let endpoint = "files/list?\(queryString)"

    let data = try await makeRequest(endpoint: endpoint, method: "GET")
    let response = try JSONDecoder().decode(APIResponse<FileListData>.self, from: data)
    guard let fileData = response.data else {
        throw APIError.invalidResponse
    }
    return fileData
}

// Upload file
func uploadFile(filename: String, data: Data) async throws -> FileUploadResponse {
    let base64 = data.base64EncodedString()
    let request = FileUploadRequest(filename: filename, data: base64)

    let encoder = JSONEncoder()
    let body = try encoder.encode(request)

    let responseData = try await makeRequest(endpoint: "files/upload", method: "POST", body: body)
    let response = try JSONDecoder().decode(APIResponse<FileUploadResponse>.self, from: responseData)
    guard let result = response.data else {
        throw APIError.invalidResponse
    }
    return result
}

// Delete file
func deleteFile(id: Int) async throws {
    _ = try await makeRequest(endpoint: "files/\(id)", method: "DELETE")
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// List files
$items['api/admin/files/list'] = array(
  'title' => 'File List',
  'page callback' => 'backdrop_admin_api_file_list',
  'access arguments' => array('access files overview'),
  'type' => MENU_CALLBACK,
);

// Upload file
$items['api/admin/files/upload'] = array(
  'title' => 'Upload File',
  'page callback' => 'backdrop_admin_api_file_upload',
  'access arguments' => array('upload files'),
  'type' => MENU_CALLBACK,
);

// Delete file
$items['api/admin/files/%'] = array(
  'title' => 'Delete File',
  'page callback' => 'backdrop_admin_api_file_delete',
  'page arguments' => array(3),
  'access arguments' => array('delete files'),
  'type' => MENU_CALLBACK,
);
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/files/list
 */
function backdrop_admin_api_file_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 50;
    $search = isset($_GET['search']) ? $_GET['search'] : NULL;
    $type = isset($_GET['type']) ? $_GET['type'] : NULL;

    $offset = ($page - 1) * $limit;

    // Build query
    $query = db_select('file_managed', 'f')
      ->fields('f')
      ->range($offset, $limit)
      ->orderBy('timestamp', 'DESC');

    // Search filter
    if ($search) {
      $query->condition('filename', '%' . db_like($search) . '%', 'LIKE');
    }

    // Type filter
    if ($type) {
      switch ($type) {
        case 'image':
          $query->condition('filemime', 'image/%', 'LIKE');
          break;
        case 'video':
          $query->condition('filemime', 'video/%', 'LIKE');
          break;
        case 'audio':
          $query->condition('filemime', 'audio/%', 'LIKE');
          break;
        case 'document':
          $query->condition('filemime', array('application/pdf', 'application/msword', 'application/vnd.ms-excel'), 'IN');
          break;
      }
    }

    $results = $query->execute();

    // Get total count
    $count_query = db_select('file_managed', 'f');
    if ($search) {
      $count_query->condition('filename', '%' . db_like($search) . '%', 'LIKE');
    }
    if ($type) {
      // Apply same type filter
    }
    $total = $count_query->countQuery()->execute()->fetchField();

    // Format results
    $items = array();
    foreach ($results as $file) {
      // Get uploader
      $user = user_load($file->uid);

      // Get usage count
      $usage_count = db_query(
        "SELECT COUNT(*) FROM {file_usage} WHERE fid = :fid",
        array(':fid' => $file->fid)
      )->fetchField();

      $items[] = array(
        'fid' => (int)$file->fid,
        'filename' => $file->filename,
        'uri' => $file->uri,
        'url' => file_create_url($file->uri),
        'filemime' => $file->filemime,
        'filesize' => (int)$file->filesize,
        'timestamp' => (int)$file->timestamp,
        'uid' => (int)$file->uid,
        'username' => $user ? $user->name : 'Unknown',
        'usage_count' => (int)$usage_count,
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
    watchdog('backdrop_admin_api', 'File list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load files: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/files/upload
 */
function backdrop_admin_api_file_upload() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $input = file_get_contents('php://input');
    $data = backdrop_json_decode($input);

    if (!$data || empty($data['filename']) || empty($data['data'])) {
      throw new Exception('Invalid upload data');
    }

    // Decode base64
    $binary = base64_decode($data['data']);
    if (!$binary) {
      throw new Exception('Failed to decode file data');
    }

    // Save file
    $filename = $data['filename'];
    $file = file_save_data($binary, 'public://' . $filename, FILE_EXISTS_RENAME);

    if (!$file) {
      throw new Exception('Failed to save file');
    }

    // Make file permanent
    $file->status = FILE_STATUS_PERMANENT;
    file_save($file);

    $response = array(
      'success' => TRUE,
      'message' => 'File uploaded successfully',
      'data' => array(
        'fid' => (int)$file->fid,
        'filename' => $file->filename,
        'url' => file_create_url($file->uri),
        'uri' => $file->uri,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'File upload error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Upload failed: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for DELETE /api/admin/files/{fid}
 */
function backdrop_admin_api_file_delete($fid) {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Check request method
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
      throw new Exception('Invalid request method');
    }

    $file = file_load($fid);
    if (!$file) {
      throw new Exception('File not found');
    }

    // Check if file is in use
    $usage = file_usage_list($file);
    if (!empty($usage)) {
      throw new Exception('Cannot delete file: it is currently in use');
    }

    // Delete file
    file_delete($file);

    $response = array(
      'success' => TRUE,
      'message' => 'File deleted successfully',
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'File delete error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Delete failed: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}
```

### Database Requirements
**Existing tables**:
- `file_managed` - File metadata
- `file_usage` - Track file usage in entities

### Backdrop API Used
- `file_create_url()` - Generate public URL
- `file_save_data()` - Save uploaded file
- `file_load()` - Load file object
- `file_delete()` - Delete file
- `file_usage_list()` - Check where file is used
- `user_load()` - Get uploader info

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager`
- ✅ `APIClient`
- ✅ `APIResponse<T>`
- ⚠️ Image picker for camera/library
- ⚠️ Grid layout for thumbnails

### From Server:
- ✅ `hook_menu()`
- ✅ Standard response format
- ✅ File API

---

## API Specification

### List Files
```
GET /api/admin/files/list?page=1&limit=50&search=&type=image
```

**Response**:
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "fid": 12,
        "filename": "photo.jpg",
        "uri": "public://photo.jpg",
        "url": "http://example.com/sites/default/files/photo.jpg",
        "filemime": "image/jpeg",
        "filesize": 524288,
        "timestamp": 1701234567,
        "uid": 1,
        "username": "admin",
        "usage_count": 3
      }
    ],
    "total": 42,
    "page": 1,
    "limit": 50
  }
}
```

### Upload File
```
POST /api/admin/files/upload
```

**Request**:
```json
{
  "filename": "new-photo.jpg",
  "data": "base64_encoded_data..."
}
```

**Response**:
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "fid": 13,
    "filename": "new-photo.jpg",
    "url": "http://example.com/sites/default/files/new-photo.jpg",
    "uri": "public://new-photo.jpg"
  }
}
```

### Delete File
```
DELETE /api/admin/files/12
```

**Response**:
```json
{
  "success": true,
  "message": "File deleted successfully"
}
```

---

## Implementation Notes

### Design Decisions
1. **Grid view for images** - Visual browsing
2. **Base64 upload** - Consistent with content editing
3. **Prevent deletion of used files** - Avoid broken references
4. **Usage tracking** - Show where files are used

### Potential Improvements
- [ ] Bulk upload
- [ ] Image editing (crop, resize)
- [ ] Folder organization
- [ ] File tagging
- [ ] Sort by size, name, date

---

## For AI Implementers

### iOS Tasks:
1. Create `FileManagementView.swift`
2. Create `FileManagementViewModel.swift`
3. Create `FileCard` component
4. Implement grid layout
5. Add camera/library picker
6. Add delete confirmation
7. Add methods to `APIClient.swift`

### Server Tasks:
1. Add routes for list/upload/delete
2. Implement callbacks
3. Handle base64 decoding
4. Check file usage before delete
5. Test with various file types
