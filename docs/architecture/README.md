# Backdrop Admin iOS - Architecture Documentation

This directory contains comprehensive architecture documentation for all features in the Backdrop Admin iOS application.

## Purpose

These documents are designed to enable **parallel implementation** across multiple AI assistants or developers. Each feature is fully specified with clear dependencies on shared infrastructure, allowing independent implementation and integration.

## Document Structure

Each feature document includes:
- **Overview** - User story and feature description
- **UI Components** - SwiftUI views, layouts, and navigation
- **iOS Client Components** - Data models, ViewModels, API methods
- **Server Components** - Backdrop module routes, callbacks, database queries
- **API Specification** - Complete REST endpoint documentation
- **Common Infrastructure Dependencies** - What this feature relies on
- **Implementation Notes** - Design decisions and considerations
- **For AI Implementers** - Specific implementation tasks and checklists

---

## Common Infrastructure

**Start here**: All features depend on shared infrastructure documented in:

### [00-common-infrastructure.md](00-common-infrastructure.md)

This document covers:
- **AuthManager** - Authentication and session management
- **APIClient** - HTTP request handling and API communication
- **Data Models** - Standard response formats and type safety patterns
- **Backdrop Module Structure** - Server-side conventions and APIs
- **Error Handling** - Patterns for both iOS and server
- **Testing** - Strategies for development and QA

**Read this first** before implementing any feature!

---

## Feature Documentation

### ✅ Implemented (Reference Examples)

These features are **already working** and serve as reference implementations:

| Document | Feature | Complexity | Key Patterns |
|----------|---------|------------|--------------|
| [01-cache-clear.md](01-cache-clear.md) | **Clear Cache** | ⭐ Simple | Single-action POST, loading states, success feedback |
| [02-status-report.md](02-status-report.md) | **Status Report** | ⭐⭐ Moderate | Data fetching, sheet modal, list display, color coding |

Use these as templates when implementing similar features.

---

### 📋 Planned Features

#### Content Management

| Document | Feature | Complexity | Dependencies |
|----------|---------|------------|--------------|
| [03-content-list.md](03-content-list.md) | **Content List** | ⭐⭐⭐ Complex | AuthManager, APIClient, pagination, search |
| [04-content-edit.md](04-content-edit.md) | **Content Edit** | ⭐⭐⭐⭐ Very Complex | AuthManager, APIClient, camera integration, image handling |

**Notes**:
- Content List enables browsing with search/filter/pagination
- Content Edit includes native camera integration for image capture
- Both use standard Node API on server side

---

#### Asset Management

| Document | Feature | Complexity | Dependencies |
|----------|---------|------------|--------------|
| [05-file-management.md](05-file-management.md) | **File Management** | ⭐⭐⭐ Complex | AuthManager, APIClient, camera/photo picker, grid layout |
| [06-blocks.md](06-blocks.md) | **Block Management** | ⭐⭐⭐ Complex | AuthManager, APIClient, drag-drop, region handling |

**Notes**:
- File Management includes upload from camera/library
- Blocks feature allows drag-to-reorder and enable/disable
- Both require careful UI/UX for iPad optimization

---

#### Community Management

| Document | Feature | Complexity | Dependencies |
|----------|---------|------------|--------------|
| [07-comments.md](07-comments.md) | **Comment Moderation** | ⭐⭐⭐ Complex | AuthManager, APIClient, swipe actions, bulk operations |
| [08-users.md](08-users.md) | **User Management** | ⭐⭐⭐ Complex | AuthManager, APIClient, search, filtering, avatars |

**Notes**:
- Comments uses swipe gestures for quick approve/reject
- Users includes block/unblock and password reset
- Both benefit from search and filtering

---

#### System Management

| Document | Feature | Complexity | Dependencies |
|----------|---------|------------|--------------|
| [09-run-cron.md](09-run-cron.md) | **Run Cron** | ⭐ Simple | AuthManager, APIClient (similar to Clear Cache) |
| [10-error-reports.md](10-error-reports.md) | **Error Reports** | ⭐⭐⭐ Complex | AuthManager, APIClient, severity filtering, detail views |

**Notes**:
- Run Cron follows the Clear Cache pattern exactly
- Error Reports displays watchdog logs with color-coded severity
- Both are essential admin tools

---

## Implementation Strategy

### Recommended Order

For maximum efficiency when implementing in parallel:

1. **Phase 1: Foundations** (Do First)
   - Ensure `AuthManager` and `APIClient` are stable
   - Implement **Run Cron** (easiest, validates infrastructure)

2. **Phase 2: Core Features** (Can be parallel)
   - **Content List** - Foundational for content management
   - **User Management** - Independent, moderate complexity
   - **File Management** - Independent, camera integration practice

3. **Phase 3: Advanced Features** (Can be parallel)
   - **Content Edit** - Builds on Content List
   - **Comment Moderation** - Independent, swipe actions
   - **Block Management** - Independent, drag-drop

4. **Phase 4: Reporting** (Can be parallel)
   - **Error Reports** - Independent, complex filtering

### Parallel Implementation Tips

When farming out to multiple AI assistants:

1. **Each assistant should read**:
   - `00-common-infrastructure.md` (shared dependencies)
   - Their specific feature document
   - Reference implementations (Cache Clear, Status Report)

2. **Each feature includes**:
   - **"Common Infrastructure Dependencies"** section listing what it needs
   - **"For AI Implementers"** section with specific tasks
   - Complete API specifications for coordination

3. **Integration points**:
   - All iOS features use `@EnvironmentObject` for AuthManager/APIClient
   - All server endpoints follow `/api/admin/{feature}/{action}` pattern
   - All responses use `APIResponse<T>` wrapper
   - Navigation integration happens in `ContentView.swift` MainView

4. **Testing independently**:
   - iOS features can be tested with mock API responses
   - Server endpoints can be tested with curl/Postman
   - Integration testing happens after both sides complete

---

## Complexity Ratings

- ⭐ **Simple** - 1-2 hours implementation
- ⭐⭐ **Moderate** - 3-5 hours implementation
- ⭐⭐⭐ **Complex** - 1-2 days implementation
- ⭐⭐⭐⭐ **Very Complex** - 2-3 days implementation

---

## Key Design Principles

All features follow these principles:

### iOS Side
1. **MVVM Architecture** - Clear separation of View, ViewModel, Model
2. **SwiftUI Native** - No external dependencies
3. **Async/Await** - Modern concurrency for all API calls
4. **Loading States** - Always show feedback during operations
5. **Error Handling** - User-friendly error messages
6. **iPad First** - Optimized for iPad but works on iPhone

### Server Side
1. **RESTful APIs** - Standard HTTP methods and endpoints
2. **JSON Responses** - Consistent `APIResponse<T>` format
3. **Access Control** - Permissions via `access arguments`
4. **Error Logging** - Watchdog logging for debugging
5. **Built-in APIs** - Leverage Backdrop's existing functions
6. **No Database Changes** - Use existing tables

---

## Getting Started

### For New Implementers

1. **Read** `00-common-infrastructure.md` thoroughly
2. **Review** reference implementations (01, 02)
3. **Choose** a feature matching your skill level
4. **Implement** following the task list in "For AI Implementers"
5. **Test** independently before integration
6. **Integrate** by adding to MainView navigation

### For Project Coordinators

1. **Assign** features to different developers/assistants
2. **Ensure** each reads common infrastructure doc
3. **Track** progress via checklist in each feature doc
4. **Integrate** completed features into main app
5. **Test** integrated features end-to-end

---

## Questions or Issues?

If you find:
- **Missing information** in a feature doc
- **Unclear dependencies** between features
- **Conflicts** in the architecture
- **Better approaches** to implementation

Please document your findings and proposed solutions.

---

## Document Maintenance

When updating these documents:

1. **Keep common infrastructure in sync** - Update `00-common-infrastructure.md` first
2. **Update affected features** - Propagate changes to feature docs
3. **Maintain consistency** - Use same structure across all docs
4. **Version carefully** - Note breaking changes

---

## Summary

This architecture documentation provides:
- ✅ **Complete specifications** for all features
- ✅ **Clear dependencies** enabling parallel work
- ✅ **Reference implementations** as templates
- ✅ **iOS and server components** fully defined
- ✅ **API contracts** for coordination
- ✅ **Implementation checklists** for each feature

**Everything you need to implement the Backdrop Admin iOS app is documented here.**

Happy coding! 🚀
