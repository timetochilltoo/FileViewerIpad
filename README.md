# FileViewer for iPad

FileViewer is a native iPadOS Markdown and PDF reading workspace. It is being migrated selectively from the existing macOS FileViewer while using iPad-native document access, multiple-window, layout, and testing architecture.

## Current status

Phase 0, Phase 1, and the simulator-verified Phase 2 implementation are complete.
The app now includes:

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
- versioned per-scene tab and selection restoration through existing bookmark
  identities, with bounded metadata-only records
- safe stale/missing-document recovery that skips inaccessible tabs and explains
  how to reopen them from Files
- explicit New Window and Open in New Window actions plus targeted activation of
  an already-owning scene
- deterministic Markdown/PDF UI-test injection seams
- 40 unit tests and 5 UI tests passing on the dedicated iPad simulator

Scene restoration is covered by a real terminate/relaunch UI test, and stale
bookmark recovery is covered by a separate UI test. Physical-device signing,
manual Files/iCloud-provider acceptance, and Phase 3 responsive/accessibility and
large-document hardening remain outstanding.

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
