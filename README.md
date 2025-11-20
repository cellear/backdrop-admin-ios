# Backdrop Admin iOS App

A native iPad application for managing Backdrop CMS sites, focusing on content management, user management, and administrative tasks that are better suited for a native iOS interface than Safari.

## Overview

This app complements (rather than replaces) Backdrop's web interface, providing native iOS experiences for common administrative tasks while linking to Safari for complex operations that are better handled in the browser.

## Features

### ✅ Implemented
- **Authentication** - Login to Backdrop sites with cookie-based sessions
- **Clear Cache** - One-tap cache clearing
- **Status Report** - View system status and requirements
- **Debug Info Panel** - Real-time debugging information for troubleshooting

### 🚧 In Progress
- **Login** - Working on resolving 404 errors when connecting via IP address

### 📋 Planned
- Content List & Browsing
- Content Editing (with camera integration)
- Comments Moderation
- File Management
- Block Editing
- User Management
- Reports Dashboard
- Error Reports

See [WORKING_ON.md](WORKING_ON.md) for current tasks and [RECENT_WORK.md](RECENT_WORK.md) for recent progress.

## Architecture

- **Framework**: SwiftUI
- **Minimum iOS**: 17.0
- **Pattern**: MVVM with Coordinator pattern
- **Backend**: Custom Backdrop module (`backdrop_admin_api`) providing JSON API endpoints

## Setup

1. Open `BackdropAdmin.xcodeproj` in Xcode
2. Select your target device (iPad recommended)
3. Build and run

## Configuration

### Local Development (DDev)

For local development with DDev:
- Site URL: `http://192.168.30.85` (or your Mac's IP)
- The app automatically adds the Host header for DDev routing
- Username/Password: Your Backdrop admin credentials

### Production

For production sites:
- Use the full site URL (e.g., `https://example.com`)
- Ensure the `backdrop_admin_api` module is installed and enabled

## Backend Requirements

This app requires the custom `backdrop_admin_api` module to be installed on your Backdrop site. The module provides JSON API endpoints for:
- Authentication (uses standard Backdrop login)
- Cache management
- Status reports
- Content management (planned)
- User management (planned)
- And more...

See the Backdrop module documentation in `BACKDROP/modules/custom/backdrop_admin_api/`.

## License

[Add your license here]

## Contributing

[Add contribution guidelines if needed]


