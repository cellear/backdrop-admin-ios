# Feature: Block Management

**Status**: 📋 **PLANNED**

**Category**: Asset Management

---

## Overview

Manage blocks (content regions) including enabling/disabling, reordering, and basic configuration. Complex block configuration falls back to web interface.

**User Story**: As an admin, I want to quickly enable/disable blocks and adjust their placement so I can manage my site layout from my iPad.

---

## UI Components

### Main View
`BlockManagementView` - List of blocks organized by region with drag-to-reorder.

### Visual Design
- **Region Sections** - Collapsible sections for each theme region (Header, Sidebar, Footer, etc.)
- **Block Cards** - Display block title, type, enabled status
- **Drag Handles** - Reorder blocks within region
- **Toggle Switch** - Enable/disable blocks
- **Empty State** - "No blocks in this region"

### View Hierarchy
```
NavigationView
└── List
    ├── Section: Header Region
    │   └── BlockRow (repeating, draggable)
    ├── Section: Sidebar Region
    │   └── BlockRow (repeating, draggable)
    └── Section: Footer Region
        └── BlockRow (repeating, draggable)
```

### Block Row Component

**Visual Elements**:
- **Drag Handle** - Three-line icon
- **Block Title** - Main text
- **Block Type** - Subtitle (System, Menu, Custom, View)
- **Region Badge** - Current region name
- **Enable Toggle** - Switch to enable/disable
- **Actions** - Configure (opens Safari)

---

## iOS Client Components

### Data Models

```swift
// Block list response
struct BlockListData: Codable {
    let regions: [BlockRegion]
    let availableRegions: [String]
}

// Region with blocks
struct BlockRegion: Codable, Identifiable {
    let id: String          // Region machine name
    let name: String        // Region display name
    let blocks: [Block]
}

// Individual block
struct Block: Codable, Identifiable {
    let id: String          // Module + delta
    let module: String      // Providing module
    let delta: String       // Block delta
    let title: String       // Admin title
    let region: String      // Current region
    let weight: Int         // Order within region
    let status: Int         // 1 = enabled, 0 = disabled
    let theme: String       // Theme name

    enum CodingKeys: String, CodingKey {
        case id = "bid"
        case module, delta, title, region, weight, status, theme
    }
}

// Update request
struct BlockUpdateRequest: Codable {
    let blocks: [BlockUpdate]
}

struct BlockUpdate: Codable {
    let id: String
    let region: String
    let weight: Int
    let status: Int

    enum CodingKeys: String, CodingKey {
        case id = "bid"
        case region, weight, status
    }
}
```

### View Model

```swift
class BlockManagementViewModel: ObservableObject {
    @Published var regions: [BlockRegion] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var hasUnsavedChanges = false

    private let apiClient: APIClient

    func loadBlocks() async {
        // Load blocks organized by region
    }

    func toggleBlock(id: String) {
        // Toggle block enabled/disabled
        hasUnsavedChanges = true
    }

    func moveBlock(id: String, to region: String, position: Int) {
        // Move block to new region/position
        hasUnsavedChanges = true
    }

    func saveChanges() async throws {
        // Send updates to server
    }
}
```

### API Methods

**Location**: Add to `APIClient.swift`

```swift
// Get blocks
func getBlocks(theme: String = "default") async throws -> BlockListData {
    let data = try await makeRequest(endpoint: "blocks/list?theme=\(theme)", method: "GET")
    let response = try JSONDecoder().decode(APIResponse<BlockListData>.self, from: data)
    guard let blockData = response.data else {
        throw APIError.invalidResponse
    }
    return blockData
}

// Update blocks
func updateBlocks(updates: BlockUpdateRequest) async throws {
    let encoder = JSONEncoder()
    let body = try encoder.encode(updates)
    _ = try await makeRequest(endpoint: "blocks/update", method: "POST", body: body)
}
```

---

## Server Components (Backdrop)

### Route Definitions

```php
// List blocks
$items['api/admin/blocks/list'] = array(
  'title' => 'Block List',
  'page callback' => 'backdrop_admin_api_block_list',
  'access arguments' => array('administer blocks'),
  'type' => MENU_CALLBACK,
);

// Update blocks
$items['api/admin/blocks/update'] = array(
  'title' => 'Update Blocks',
  'page callback' => 'backdrop_admin_api_block_update',
  'access arguments' => array('administer blocks'),
  'type' => MENU_CALLBACK,
);
```

### Callback Functions

```php
/**
 * Callback for GET /api/admin/blocks/list
 */
function backdrop_admin_api_block_list() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $theme = isset($_GET['theme']) ? $_GET['theme'] : config_get('system.core', 'theme_default');

    // Get all blocks for theme
    $blocks = db_select('block', 'b')
      ->fields('b')
      ->condition('theme', $theme)
      ->orderBy('region')
      ->orderBy('weight')
      ->execute()
      ->fetchAll();

    // Get theme regions
    $theme_info = list_themes()[$theme];
    $regions = $theme_info->info['regions'];

    // Organize blocks by region
    $block_regions = array();
    foreach ($regions as $region_key => $region_name) {
      $region_blocks = array();

      foreach ($blocks as $block) {
        if ($block->region === $region_key && $block->status == 1) {
          $region_blocks[] = array(
            'bid' => $block->module . '_' . $block->delta,
            'module' => $block->module,
            'delta' => $block->delta,
            'title' => $block->title ?: _block_get_default_title($block),
            'region' => $block->region,
            'weight' => (int)$block->weight,
            'status' => (int)$block->status,
            'theme' => $block->theme,
          );
        }
      }

      $block_regions[] = array(
        'id' => $region_key,
        'name' => $region_name,
        'blocks' => $region_blocks,
      );
    }

    $response = array(
      'success' => TRUE,
      'data' => array(
        'regions' => $block_regions,
        'availableRegions' => array_keys($regions),
      ),
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Block list error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Failed to load blocks: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Callback for POST /api/admin/blocks/update
 */
function backdrop_admin_api_block_update() {
  backdrop_add_http_header('Content-Type', 'application/json');

  try {
    $input = file_get_contents('php://input');
    $data = backdrop_json_decode($input);

    if (!$data || empty($data['blocks'])) {
      throw new Exception('No block updates provided');
    }

    foreach ($data['blocks'] as $block_update) {
      // Parse bid (module_delta)
      list($module, $delta) = explode('_', $block_update['bid'], 2);

      // Update block
      db_update('block')
        ->fields(array(
          'region' => $block_update['region'],
          'weight' => $block_update['weight'],
          'status' => $block_update['status'],
        ))
        ->condition('module', $module)
        ->condition('delta', $delta)
        ->execute();
    }

    // Clear block cache
    cache_clear_all('*', 'cache_block', TRUE);

    $response = array(
      'success' => TRUE,
      'message' => 'Blocks updated successfully',
    );
  } catch (Exception $e) {
    watchdog('backdrop_admin_api', 'Block update error: @error',
      array('@error' => $e->getMessage()),
      WATCHDOG_ERROR
    );

    $response = array(
      'success' => FALSE,
      'message' => 'Update failed: ' . $e->getMessage(),
    );
  }

  print backdrop_json_encode($response);
  backdrop_exit();
}

/**
 * Helper to get default block title
 */
function _block_get_default_title($block) {
  $info = module_invoke($block->module, 'block_info');
  return isset($info[$block->delta]['info']) ? $info[$block->delta]['info'] : 'Untitled';
}
```

### Database Requirements
**Existing tables**:
- `block` - Block configuration

### Backdrop API Used
- `config_get()` - Get default theme
- `list_themes()` - Get theme info
- `module_invoke()` - Get block info
- `cache_clear_all()` - Clear block cache

---

## API Specification

### List Blocks
```
GET /api/admin/blocks/list?theme=default
```

**Response**:
```json
{
  "success": true,
  "data": {
    "regions": [
      {
        "id": "header",
        "name": "Header",
        "blocks": [
          {
            "bid": "system_main-menu",
            "module": "system",
            "delta": "main-menu",
            "title": "Main menu",
            "region": "header",
            "weight": 0,
            "status": 1,
            "theme": "default"
          }
        ]
      }
    ],
    "availableRegions": ["header", "sidebar_first", "content", "footer"]
  }
}
```

### Update Blocks
```
POST /api/admin/blocks/update
```

**Request**:
```json
{
  "blocks": [
    {
      "bid": "system_main-menu",
      "region": "sidebar_first",
      "weight": 5,
      "status": 1
    }
  ]
}
```

---

## For AI Implementers

### iOS Tasks:
1. Create `BlockManagementView.swift`
2. Implement drag-and-drop reordering
3. Add enable/disable toggles
4. Track unsaved changes
5. Add save confirmation

### Server Tasks:
1. Add routes
2. Implement list/update callbacks
3. Handle block ID parsing
4. Clear caches after update
