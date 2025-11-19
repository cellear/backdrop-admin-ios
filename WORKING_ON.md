# Current Work & TODO

## 🔴 High Priority - Blocking

### Login Issues
- **Problem**: Getting 404 errors when logging in via IP address (`http://192.168.30.85`)
- **Status**: Debugging in progress
- **Details**: 
  - Host header is being sent correctly (`backdrop-for-ios.ddev.site`)
  - DDev router still returns 404
  - Need to test with hostname URL instead of IP
- **Next Steps**:
  - Try using `http://backdrop-for-ios.ddev.site` directly
  - Investigate DDev router configuration
  - Consider App Transport Security settings

## 🟡 Medium Priority

### Feature Implementation
- **Run Cron** - API endpoint exists, needs UI implementation
- **Content List** - Design and implement list view with search/filter
- **Content Editing** - Native editor with camera integration
- **Comments Moderation** - Quick approve/reject workflow

## 🟢 Low Priority

### UI/UX Improvements
- Improve error messages
- Add loading states for all API calls
- Better offline handling
- Add haptic feedback for actions

### Documentation
- API endpoint documentation
- User guide
- Development setup guide

## 📝 Backend Tasks

### Backdrop Module (`backdrop_admin_api`)
- Implement content list endpoint (`GET /api/admin/content`)
- Implement content CRUD endpoints
- Implement comments endpoints
- Implement files endpoints
- Implement blocks endpoints
- Implement users endpoints
- Implement logs endpoint (`GET /api/admin/reports/logs`)

## 🎯 Future Considerations

- Push notifications for new comments/errors
- Widget support
- Siri Shortcuts
- iPad-specific features (split view, drag & drop, Apple Pencil)

