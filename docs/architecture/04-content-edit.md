# Feature: Content Edit

**Status**: 📋 **PLANNED**

**Category**: Content Management

---

## Overview

Native content creation and editing interface optimized for iPad. Supports text editing, image capture from camera, and basic formatting. Complex operations (like layout builders) fall back to Safari.

**User Story**: As an admin, I want to create and edit content on my iPad using native controls and the camera so I can quickly publish updates while mobile.

---

## UI Components

### Main View
`ContentEditView` - Full-screen form with fields for node creation/editing.

### Visual Design
- **Navigation Bar** with "Edit Content" title, "Cancel" and "Save" buttons
- **Form Fields** - Title, body, content type selector, status, images
- **Image Section** - Camera button, photo library, existing images
- **Rich Text Editor** - Basic formatting (bold, italic, links)
- **Metadata Section** - Publishing options (status, promoted, sticky)
- **Save Actions** - Save, Save & View, Save as Draft
- **Loading State** - Disabled fields with spinner
- **Unsaved Changes Alert** - Warning when navigating away

### View Hierarchy
```
NavigationView
└── Form
    ├── Section: Basic Info
    │   ├── TextField (Title)
    │   └── Picker (Content Type) [create only]
    ├── Section: Body
    │   └── TextEditor (with formatting toolbar)
    ├── Section: Images
    │   ├── Image Preview Grid
    │   ├── Add from Camera Button
    │   └── Add from Library Button
    ├── Section: Publishing Options
    │   ├── Toggle (Published/Draft)
    │   ├── Toggle (Promoted to front page)
    │   └── Toggle (Sticky at top of lists)
    └── Section: Actions
        ├── Save Button
        └── Save & View Button
```

### Image Handling
- **Camera Integration** - Use `UIImagePickerController` for photo capture
- **Photo Library** - Select from existing photos
- **Preview Grid** - Thumbnail grid of attached images
- **Reordering** - Drag to reorder images
- **Delete** - Swipe to delete images

### Rich Text Toolbar
Simple formatting options:
- **Bold**, **Italic**, **Link**
- Headings (H2, H3)
- Lists (bulleted, numbered)
- "View HTML" button for advanced users

---

## iOS Client Components

### Data Models

```swift
// Full node data for editing
struct NodeDetail: Codable {
    let nid: Int?               // nil for new nodes
    let title: String
    let type: String
    let body: String?
    let bodyFormat: String?     // "filtered_html", "full_html", etc.
    let status: Int             // 1 = published, 0 = draft
    let promote: Int            // 1 = promoted, 0 = not
    let sticky: Int             // 1 = sticky, 0 = not
    let images: [NodeImage]?
    let created: Int?
    let changed: Int?

    enum CodingKeys: String, CodingKey {
        case nid, title, type, body, status, promote, sticky, images, created, changed
        case bodyFormat = "body_format"
    }
}

// Image attachment
struct NodeImage: Codable, Identifiable {
    let id: Int?                // File ID (nil for new uploads)
    let url: String?            // URL for existing images
    let alt: String?            // Alt text
    let title: String?          // Image title
    let data: String?           // Base64 encoded data for uploads

    enum CodingKeys: String, CodingKey {
        case id = "fid"
        case url, alt, title, data
    }
}

// Create/update request
struct NodeSaveRequest: Codable {
    let title: String
    let type: String?           // Only for creation
    let body: String?
    let bodyFormat: String?
    let status: Int
    let promote: Int
    let sticky: Int
    let images: [NodeImageUpload]?

    enum CodingKeys: String, CodingKey {
        case title, type, body, status, promote, sticky, images
        case bodyFormat = "body_format"
    }
}

// Image for upload
struct NodeImageUpload: Codable {
    let data: String            // Base64 encoded
    let filename: String
    let alt: String?
    let title: String?
}

// Response after save
struct NodeSaveResponse: Codable {
    let nid: Int
    let title: String
    let url: String             // View URL
}
```

### View Model

```swift
class ContentEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var contentType: String = "page"
    @Published var status: Int = 1
    @Published var promote: Int = 0
    @Published var sticky: Int = 0
    @Published var images: [UIImage] = []
    @Published var existingImages: [NodeImage] = []

    @Published var isSaving = false
    @Published var hasUnsavedChanges = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let nodeId: Int?    // nil for new nodes

    init(apiClient: APIClient, nodeId: Int? = nil) {
        self.apiClient = apiClient
        self.nodeId = nodeId
    }

    func loadNode() async {
        // Load existing node data
    }

    func saveNode() async throws -> NodeSaveResponse {
        // Save changes or create new node
    }

    func addImage(_ image: UIImage) {
        // Add image to queue
        images.append(image)
        hasUnsavedChanges = true
    }

    func removeImage(at index: Int) {
        // Remove image
    }

    private func imageToBase64(_ image: UIImage) -> String {
        // Convert UIImage to base64 string
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get node for editing
func getNode(id: Int) async throws -> NodeDetail {
    let data = try await makeRequest(endpoint: "content/\(id)", method: "GET")
    let response = try JSONDecoder().decode(APIResponse<NodeDetail>.self, from: data)
    guard let node = response.data else {
        throw APIError.invalidResponse
    }
    return node
}

// Create new node
func createNode(request: NodeSaveRequest) async throws -> NodeSaveResponse {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let body = try encoder.encode(request)

    let data = try await makeRequest(endpoint: "content/create", method: "POST", body: body)
    let response = try JSONDecoder().decode(APIResponse<NodeSaveResponse>.self, from: data)
    guard let result = response.data else {
        throw APIError.invalidResponse
    }
    return result
}

// Update existing node
func updateNode(id: Int, request: NodeSaveRequest) async throws -> NodeSaveResponse {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let body = try encoder.encode(request)

    let data = try await makeRequest(endpoint: "content/\(id)", method: "PUT", body: body)
    let response = try JSONDecoder().decode(APIResponse<NodeSaveResponse>.self, from: data)
    guard let result = response.data else {
        throw APIError.invalidResponse
    }
    return result
}
```

### Camera Integration

```swift
import PhotosUI

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
    }
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// Get node for editing
$items['api/admin/content/%'] = array(
  'title' => 'Get Node',
  'page callback' => 'backdrop_admin_api_get_node',
  'page arguments' => array(3),  // Node ID from URL
  'access arguments' => array('edit any page content'),  // Adjust per type
  'type' => MENU_CALLBACK,
);

// Create new node
$items['api/admin/content/create'] = array(
  'title' => 'Create Node',
  'page callback' => 'backdrop_admin_api_create_node',
  'access arguments' => array('create page content'),
  'type' => MENU_CALLBACK,
);

// Update existing node (same path as get, different method)
// Note: Backdrop's hook_menu doesn't distinguish by HTTP method,
// so we'll handle PUT in the callback based on $_SERVER['REQUEST_METHOD']
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/content/{nid}
 */
function backdrop_admin_api_get_node($nid) {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Load node
    $node = node_load($nid);

    if (!$node) {
      throw new Exception('Node not found');
    }

    // Check edit access
    if (!node_access('update', $node)) {
      backdrop_add_http_header('Status', '403 Forbidden');
      throw new Exception('Access denied');
    }

    // Get body field
    $body = '';
    $body_format = 'filtered_html';
    if (isset($node->body) && !empty($node->body)) {
      $body_field = field_get_items('node', $node, 'body');
      if ($body_field) {
        $body = $body_field[0]['value'];
        $body_format = $body_field[0]['format'];
      }
    }

    // Get images
    $images = array();
    if (isset($node->field_image) && !empty($node->field_image)) {
      $image_items = field_get_items('node', $node, 'field_image');
      if ($image_items) {
        foreach ($image_items as $image) {
          $file = file_load($image['fid']);
          $images[] = array(
            'fid' => (int)$file->fid,
            'url' => file_create_url($file->uri),
            'alt' => isset($image['alt']) ? $image['alt'] : '',
            'title' => isset($image['title']) ? $image['title'] : '',
          );
        }
      }
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'nid' => (int)$node->nid,
        'title' => $node->title,
        'type' => $node->type,
        'body' => $body,
        'body_format' => $body_format,
        'status' => (int)$node->status,
        'promote' => (int)$node->promote,
        'sticky' => (int)$node->sticky,
        'images' => $images,
        'created' => (int)$node->created,
        'changed' => (int)$node->changed,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Get node error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/content/create and PUT /api/admin/content/{nid}
 */
function backdrop_admin_api_create_node() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    // Get JSON input
    $input = file_get_contents('php://input');
    $data = backdrop_json_decode($input);

    if (!$data) {
      throw new Exception('Invalid JSON input');
    }

    // Validate required fields
    if (empty($data['title'])) {
      throw new Exception('Title is required');
    }
    if (empty($data['type'])) {
      throw new Exception('Content type is required');
    }

    // Create new node
    $node = new Node();
    $node->type = $data['type'];
    $node->title = $data['title'];
    $node->language = LANGUAGE_NONE;
    $node->uid = $GLOBALS['user']->uid;
    $node->status = isset($data['status']) ? $data['status'] : 1;
    $node->promote = isset($data['promote']) ? $data['promote'] : 0;
    $node->sticky = isset($data['sticky']) ? $data['sticky'] : 0;
    $node->comment = COMMENT_NODE_OPEN;

    // Set body
    if (!empty($data['body'])) {
      $node->body[LANGUAGE_NONE][0]['value'] = $data['body'];
      $node->body[LANGUAGE_NONE][0]['format'] = isset($data['body_format']) ? $data['body_format'] : 'filtered_html';
    }

    // Handle images
    if (!empty($data['images'])) {
      $fids = array();
      foreach ($data['images'] as $image_data) {
        // Decode base64 image
        $binary = base64_decode($image_data['data']);

        // Create file object
        $filename = isset($image_data['filename']) ? $image_data['filename'] : 'image.jpg';
        $file = file_save_data($binary, 'public://' . $filename, FILE_EXISTS_RENAME);

        if ($file) {
          $node->field_image[LANGUAGE_NONE][] = array(
            'fid' => $file->fid,
            'alt' => isset($image_data['alt']) ? $image_data['alt'] : '',
            'title' => isset($image_data['title']) ? $image_data['title'] : '',
          );
          $fids[] = $file->fid;
        }
      }
    }

    // Save node
    node_save($node);

    // Get view URL
    $url = url('node/' . $node->nid, array('absolute' => TRUE));

    $response = array(
      'success' => TRUE,
      'message' => 'Content created successfully',
      'data' => array(
        'nid' => (int)$node->nid,
        'title' => $node->title,
        'url' => $url,
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Create node error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Update existing node - called from same endpoint, checks REQUEST_METHOD
 */
// Add logic to backdrop_admin_api_get_node to detect PUT method
// and call update function instead
```

### Database Requirements
**Existing tables**:
- `node` - Main content storage
- `field_data_body` - Body field storage
- `field_data_field_image` - Image field storage (if exists)
- `file_managed` - File/image metadata

### Backdrop API Used
- `node_load($nid)` - Load existing node
- `node_access('update', $node)` - Check permissions
- `node_save($node)` - Save new or updated node
- `field_get_items()` - Get field values
- `file_save_data()` - Save uploaded file
- `file_create_url()` - Generate public URL
- `url()` - Generate node URL
- `backdrop_json_decode()` - Parse JSON input

---

## Common Infrastructure Dependencies

### From iOS:
- ✅ `AuthManager` - For authentication
- ✅ `APIClient` - For HTTP requests
- ✅ `APIResponse<T>` - Standard response wrapper
- ⚠️ Image picker integration
- ⚠️ Rich text editor (or link to web view)
- ⚠️ Unsaved changes detection

### From Server:
- ✅ `hook_menu()` - Route registration
- ✅ Standard response format
- ✅ Node API
- ✅ File API
- ⚠️ Image field handling

---

## API Specification

### Get Node
```
GET /api/admin/content/{nid}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "nid": 123,
    "title": "My Page",
    "type": "page",
    "body": "Page content here...",
    "body_format": "filtered_html",
    "status": 1,
    "promote": 0,
    "sticky": 0,
    "images": [
      {
        "fid": 45,
        "url": "http://example.com/sites/default/files/image.jpg",
        "alt": "Alt text",
        "title": "Image title"
      }
    ],
    "created": 1701234567,
    "changed": 1701234890
  }
}
```

### Create Node
```
POST /api/admin/content/create
```

**Request**:
```json
{
  "title": "New Page",
  "type": "page",
  "body": "Content goes here...",
  "body_format": "filtered_html",
  "status": 1,
  "promote": 0,
  "sticky": 0,
  "images": [
    {
      "data": "base64_encoded_image_data...",
      "filename": "photo.jpg",
      "alt": "Photo description",
      "title": "Photo title"
    }
  ]
}
```

**Response**:
```json
{
  "success": true,
  "message": "Content created successfully",
  "data": {
    "nid": 124,
    "title": "New Page",
    "url": "http://example.com/node/124"
  }
}
```

### Update Node
```
PUT /api/admin/content/{nid}
```

Same request/response format as create.

---

## Implementation Notes

### Design Decisions
1. **Native editing for simple content** - Title, body, images only
2. **Camera integration** - Key differentiator from web interface
3. **Base64 image upload** - Simpler than multipart/form-data
4. **Limited formatting** - Avoid complexity of full WYSIWYG
5. **Fallback to web** - For complex fields, layouts, taxonomies

### Complexity Considerations
- **Medium-High** complexity
- Camera permissions handling
- Image resizing/compression
- Unsaved changes tracking
- Form validation

### Potential Improvements
- [ ] Auto-save drafts locally
- [ ] Image compression before upload
- [ ] Rich text editor with preview
- [ ] Field-level validation
- [ ] Taxonomy term selection
- [ ] URL alias editing

---

## For AI Implementers

**Key Implementation Tasks**:

### iOS Side:
1. Create `ContentEditView.swift`
2. Create `ContentEditViewModel.swift`
3. Implement camera integration with `ImagePickerView`
4. Add base64 image encoding
5. Add unsaved changes detection
6. Implement form validation
7. Add methods to `APIClient.swift`
8. Handle navigation (from list, detail, or main menu)

### Server Side:
1. Add routes for get/create/update
2. Implement `backdrop_admin_api_get_node()`
3. Implement `backdrop_admin_api_create_node()`
4. Handle base64 image decoding and file creation
5. Add proper permission checks
6. Validate input data
7. Handle different content types

### Testing:
- Test creating new content
- Test editing existing content
- Test camera integration (requires physical device)
- Test photo library integration
- Test image upload and display
- Test validation errors
- Verify permissions work correctly
