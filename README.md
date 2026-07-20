# FileViewer for iPad

FileViewer is a native iPadOS Markdown and PDF reading workspace. It is being migrated selectively from the existing macOS FileViewer while using iPad-native document access, multiple-window, layout, and testing architecture.

## Current status

Phase 0 foundation:

- iPadOS 26.0 minimum deployment target
- iPad-only application target
- independent workspace state per window
- document/tab/search/reading-position value models
- service protocols for document access, bookmarks, reading-state persistence, and security-scoped access
- app-level duplicate-document registry
- unit and UI test targets

PDF and Markdown opening/rendering begin in Phase 1.

## Requirements

- Xcode 26.6
- Swift 6
- iOS 26.5 simulator runtime
- XcodeGen

## Generate the project

The checked-in Xcode project is generated from `project.yml`:

```bash
xcodegen generate
```

When target membership or build settings change, edit `project.yml` and regenerate the project rather than making an unexplained project-file-only change.

## Build and test

```bash
xcodebuild \
  -project FileViewerIpad.xcodeproj \
  -scheme FileViewerIpad \
  -destination 'platform=iOS Simulator,name=FileViewer Test iPad,OS=26.5' \
  test
```

## Documentation

- Architecture and migration plan: `docs/IPAD_ARCHITECTURE_AND_MIGRATION_PLAN.md`
- Continuation handoff: `HANDOFF.md`

## Reference code policy

The macOS project at `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad` is read-only reference material. Never build, format, edit, commit, or generate files in that directory from this project.

