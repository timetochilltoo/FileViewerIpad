# FileViewer for iPad

FileViewer is a native iPadOS Markdown and PDF reading workspace. It is being migrated selectively from the existing macOS FileViewer while using iPad-native document access, multiple-window, layout, and testing architecture.

## Current status

Phase 0 and the Phase 1 reader implementation are complete. The current Phase 2
slice adds search and reading-position restoration while leaving scene activation
and explicit new-window routing for the next unit. The app now includes:

- iPadOS 26.0 minimum deployment target
- iPad-only application target
- independent workspace state per window
- Markdown/PDF selection through the system file importer
- coordinated, read-only file loading with balanced security-scoped access
- persistent iOS bookmark creation
- bookmark resolution and a capped, deduplicated Recent Documents list
- PDF/Markdown document-type registration, external URL handling, and file URL
  drag-and-drop
- stable document identities and duplicate-document protection
- read-only Markdown blocks with selectable inline formatting
- PDFKit continuous reading with page and zoom controls
- PDF thumbnail and outline navigation with defensive page-index validation
- per-tab case-insensitive Markdown/PDF search with match counts, highlighting,
  and explicit next/previous navigation
- versioned UserDefaults-backed reading positions for Markdown visible UTF-16
  locations and PDF page/scale, including restore hooks
- deterministic Markdown/PDF UI-test injection seams
- 28 unit tests and 3 UI tests passing on the dedicated iPad simulator

Cross-window duplicate detection is implemented, but activating the already-owning
scene and explicit open-in-new-window routing are still deferred to the
multiple-window phase. End-to-end relaunch restoration and manual Files/iCloud
acceptance remain outstanding even though the persistence and reader hooks are
implemented and unit-tested.

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
