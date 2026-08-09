# FileViewer for iPad — Handoff

Last updated: 2026-08-10
Current phase: Phase 0 and Phase 1 complete; Phase 2 search/reading restoration and scene/new-window routing slices implemented and simulator-tested; relaunch session restoration remains
Writable workspace: `/Users/patrickshi/Documents/Codex/FileViewer_iPad`  
Intended GitHub repository: `https://github.com/timetochilltoo/FileViewerIpad.git`  
Read-only macOS reference: `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad`

## 1. Project objective

Build a native iPad Markdown and PDF viewer with future AI capability by selectively migrating the existing native macOS FileViewer. The product is for Patrick's personal use on iPadOS 26.

The priority order supplied by the user is:

1. PDF viewing
2. Markdown viewing
3. document opening
4. multiple windows
5. search
6. reading-position restoration
7. responsive UI
8. later: Markdown editing
9. later: PDF annotations
10. later: PDF forms
11. later: AI integration

The user subsequently approved implementation. Phase 0 is complete. Phase 1 now
opens Markdown/PDF files through the picker, registered external-open flow, and
drag/drop; persists and resolves capped recents; reads without writing; renders both
formats; and provides defensive PDF thumbnail/outline navigation. Unit, UI, and
simulator visual checks pass. The first Phase 2 slice now adds per-tab Markdown/PDF
search, explicit result navigation, and versioned reading-position persistence for
Markdown visible UTF-16 locations and PDF page/scale. The second Phase 2 slice now
uses a Codable/Hashable `WindowGroup` payload, `openWindow(value:)`, and an app-local
scene coordinator to route new-window requests and cross-window duplicate activation
to exactly one workspace. The simulator suite passes; relaunch-level session
restoration and physical Files/iCloud acceptance remain.

## 2. Non-negotiable reference rule

`/Users/patrickshi/Documents/Codex/R_FileViewer_ipad` is reference-only.

Do not:

- edit, rename, delete, format, or generate files there
- run builds or tests there
- run package resolution there
- switch its branch
- commit, merge, pull, or push from it
- copy generated `.build`, `build`, or `dist` output into this project

Read-only inspection is allowed. All work must occur in `/Users/patrickshi/Documents/Codex/FileViewer_iPad`.

The reference was inspected without modification. At audit time:

- branch: `feature/ai-assistant`
- commit: `834c98602b20ac7a78585e1168873851359333ae`
- date: 2026-07-20
- subject: `Clarify AI assistant actions`
- initial source-audit worktree state: clean

On 2026-07-21, all updated reference documents were read again. They are currently uncommitted worktree modifications made by the other macOS agent:

- `HANDOFF.md`
- `README.md`
- `docs/ai-assistant-specification.md`
- `docs/mvp-task-list.md`
- `docs/requirements-and-specification.md`

No Swift source or test change accompanied this refresh. Do not clean, commit, or otherwise alter these reference changes from the iPad workspace.

## 3. Documentation and implementation completed

The detailed design is in:

- `docs/IPAD_ARCHITECTURE_AND_MIGRATION_PLAN.md`

That document contains:

- iPadOS compatibility decision
- all-source portability audit
- proposed project structure
- app/scene/tab state ownership
- security-scoped file-access design
- multiple-window routing
- Markdown and PDF reader design
- search and restoration design
- responsive UI rules
- privacy and security requirements
- automated test plan
- phased migration and exit criteria
- recommended first implementation slice

Future agents must read the architecture plan and this handoff before implementation.

Important implementation files now present:

```text
project.yml
FileViewerIpad.xcodeproj/
FileViewerIpad/
├── App/
│   ├── AppEnvironment.swift
│   ├── FileViewerIpadApp.swift
│   ├── OpenRequestRouter.swift
│   └── WorkspaceSceneCoordinator.swift
├── Core/FileAccess/
│   ├── DocumentAccessProtocols.swift
│   ├── DocumentAccessRegistry.swift
│   └── DocumentAccessService.swift
├── Core/Models/DocumentModels.swift
├── Core/Persistence/
│   ├── ReadingStateStore.swift
│   └── RecentDocumentStore.swift
├── Core/Search/DocumentSearchIndex.swift
├── Features/Markdown/
│   ├── MarkdownBlockParser.swift
│   └── MarkdownReaderView.swift
├── Features/PDF/PDFReaderView.swift
└── Features/Workspace/
    ├── WorkspaceModel.swift
    └── WorkspaceView.swift
FileViewerIpadTests/
├── DocumentAccessServiceTests.swift
├── DocumentAccessRegistryTests.swift
├── MarkdownBlockParserTests.swift
├── OpenRequestRouterTests.swift
├── PDFReaderModelTests.swift
├── DocumentSearchIndexTests.swift
├── ReadingStateStoreTests.swift
├── RecentDocumentStoreTests.swift
├── WorkspaceModelTests.swift
└── WorkspaceSceneCoordinatorTests.swift
FileViewerIpadUITests/
└── FileViewerIpadUITests.swift
```

The checked-in Xcode project is generated from `project.yml` with XcodeGen. Change
target membership and build settings in `project.yml`, then regenerate.

## 4. macOS reference understanding

The macOS app is a native SwiftUI application with AppKit/PDFKit bridges. The current reference Swift source is approximately 9,187 lines across 11 files:

```text
Sources/FileViewer/
├── AIAssistant.swift
├── AIAssistantPanel.swift
├── AppCommands.swift
├── ContentView.swift
├── DocumentModel.swift
├── FileViewerApp.swift
├── FileViewerWindowRegistry.swift
├── MarkdownSyntaxHelp.swift
├── MarkdownWorkspace.swift
├── PDFWorkspace.swift
└── SidebarView.swift
```

Reference tests:

```text
Tests/FileViewerTests/
├── AIAssistantTests.swift
└── DocumentSafetyTests.swift
```

The original complete 1,187-line reference `HANDOFF.md` was read before the source audit. Its updated 1,200-line version, updated `README.md`, and all three updated documents under `docs/` were read on 2026-07-21.

### 4.1 Important macOS architectural lessons

- Each window owns a separate `AppModel`; a singleton caused all windows to show the same file.
- Global file-open notifications caused every window to consume the newest Finder-open URL. iPad external-open routing must deliver each request once.
- Most per-document UI state belongs in `DocumentTab`, not globally.
- PDFKit can report `NSNotFound` page indexes. Always guard and clamp.
- PDF search highlighting must be separate from navigation. Normal view updates must not scroll back to the current match.
- Clearing search must not jump to the top.
- Markdown restoration is more stable using the first visible UTF-16 character than a pixel offset after reflow.
- PDF page/scale and Markdown positions are saved at natural lifecycle points rather than on every tiny scroll callback.
- Opening a file already present in any FileViewer tab/window brings the existing instance forward. The iPad port should enforce this one-instance-per-identity behavior from its first viewer phase, not wait until editing.
- Document contents remain local unless the user explicitly invokes configured AI.

### 4.2 Portability summary

Mostly reusable or extractable:

- AI provider/context/export logic, deferred
- document enums and value state
- file-version comparison
- Markdown type and heading detection
- Markdown block/table/task parser
- UTF-16 search math
- PDF outline extraction
- PDF invalid-index guards
- search request-ID pattern
- reading-position state records
- most of `SidebarView`'s conceptual structure
- much of the existing unit-test intent

Requires iPad adapters or conditional compilation:

- SwiftUI workspace shell
- commands and keyboard shortcuts
- AI panel
- Markdown text views
- PDFKit view wrapper
- search input
- syntax-help presentation
- colors, dialogs, printing, and file panels

AppKit-specific and should be replaced:

- `FileViewerApp.swift` lifecycle/delegate
- `FileViewerWindowRegistry.swift`
- `NSWindow` ownership and frame restore
- `NSOpenPanel`, `NSSavePanel`, `NSAlert`
- `NSViewRepresentable`, `NSTextView`, `NSScrollView`
- `NSEvent` mouse/keyboard monitors
- `NSColor` and `NSBezierPath` UI code
- `NSPrintOperation`

Do not copy the 2,628-line `DocumentModel.swift` wholesale. It mixes neutral models, file I/O, persistence, dialogs, printing, Markdown editor selection, PDF annotation history, and window/session behavior. The iPad design deliberately splits these responsibilities.

## 5. Compatibility and environment

Chosen target:

- iPadOS 26.0 minimum
- iPad only (`TARGETED_DEVICE_FAMILY = 2`)
- expected to work on iPadOS 26.x
- no lower-version compatibility requirement
- no iPhone, Mac Catalyst, visionOS, or macOS target currently planned

Local tools verified on 2026-07-20:

```text
Xcode 26.6 (17F113)
Swift 6.3.3
iOS device SDK 26.5
iOS Simulator SDK 26.5
Git 2.50.1
GitHub CLI 2.94.0
```

Simulator readiness verified on 2026-07-21:

- iOS 26.5 runtime `(23F77)` is installed and eligible in Xcode 26.6.
- Standard iPad Pro, iPad Air, iPad mini, and base iPad simulator devices are available.
- Dedicated device: `FileViewer Test iPad`
- Device UDID: `174A3DF4-AE79-42FF-A063-90ED2887FBD7`
- The device was booted automatically by the successful test run.

The simulator prerequisite, Phase 0 verification, and Phase 1A reader verification
are satisfied.

GitHub authentication was verified:

- account: `timetochilltoo`
- storage: macOS Keychain
- protocol: HTTPS
- repository permissions: admin, maintain, pull, push, and triage
- author name: `timetochilltoo`
- author email: `152804118+timetochilltoo@users.noreply.github.com`

The intended GitHub repository exists, is public, and was empty when checked. Its default branch is `main`.

The writable workspace is now a Git repository on local branch `main`, with remote:

```text
origin https://github.com/timetochilltoo/FileViewerIpad.git
```

## 6. Core iPad architecture decision

Use a native Xcode iPad application project rather than the macOS executable Swift package.

State boundaries:

```text
AppEnvironment
├── OpenRequestRouter
├── WorkspaceSceneCoordinator
├── DocumentAccessRegistry actor
├── BookmarkStore
├── RecentDocumentStore
├── ReadingStateStore
└── SceneSessionStore (planned for relaunch restoration)

WindowGroup
└── WorkspaceSceneRoot (one per Codable scene payload)
    └── WorkspaceModel (one per iPad window)
        └── tabs: [DocumentTab]
            ├── stable DocumentIdentity
            ├── MarkdownReadDocument or PDFReadDocument
            ├── search state
            └── reading-position state
```

The app environment owns services, not the selected document. Every iPad window owns its own workspace model. Every tab owns its own document-specific state.

Use:

- SwiftUI `WindowGroup` and `openWindow(value:)` for multiple windows
- `WorkspaceSceneCoordinator` queues one-shot URL/recent open requests and target
  tab activations by `WorkspaceID`; it is deliberately not a broadcast notification
- `.fileImporter`, URL handling, and drag/drop for opening
- security-scoped bookmarks for persistent Files/iCloud access
- explicit, balanced security-scope lifetimes
- PDFKit through `UIViewRepresentable`
- an iPad-adaptive `NavigationSplitView`
- a read-only `UITextView` adapter when Markdown selection, highlighting, and precise restoration require TextKit
- versioned persistence records

## 7. Security behavior to preserve

Viewer phases:

- no network traffic
- no implicit upload
- no writes into opened source documents
- no logging document or selected text
- no raw bookmark data in logs
- no automatic remote image fetching from Markdown
- no active HTML or JavaScript execution
- typed validation and bounded asynchronous work for untrusted documents

Persistent file access:

- validate supported type
- begin security scope when needed
- coordinate read
- create/refresh bookmark
- load typed document
- stop access at an explicit lifetime boundary

Future editing:

- detect external changes before overwrite
- coordinate writes
- write and verify a temporary file
- atomically replace only when safe
- prefer Save Copy for PDFs

Future AI:

- Keychain only for API keys
- local endpoints default to no remote-transfer consent
- preserve the existing LM Studio, Ollama, custom OpenAI-compatible, and OpenAI provider profiles
- remote endpoints require explicit permission to receive document text
- show the destination host
- send only after explicit user action
- keep extraction/retrieval on device
- call supplied page/heading labels request provenance, not citations
- exclude PDF form values from AI context by default
- hide and discard `<think>...</think>` reasoning
- do not give AI file mutation or shell tools

## 8. Planned implementation phases

### Phase 0: project foundation

- [x] initialize Git workspace against `FileViewerIpad.git`
- [x] create iPad-only Xcode project, unit-test target, and UI-test target
- [x] set iPadOS 26.0 and iPad-only device family
- [x] set display name `FileViewer` and bundle ID
  `com.timetochilltoo.FileViewerIpad`
- [ ] choose a signing team for physical-device builds
- [x] add platform-neutral document, tab, search, and reading-position models
- [x] add file-access, bookmark, reading-state, and security-scope protocols
- [x] add an actor registry for cross-window duplicate-document ownership
- [x] add independent per-window workspace state
- [x] add registry, workspace-isolation, and empty-workspace UI tests
- [x] build and test on `FileViewer Test iPad`

### Phase 1: secure opening and basic readers

- [x] system file importer for `.md`, `.markdown`, and `.pdf`
- [x] validate extension before reading
- [x] balance every successful security-scope start
- [x] coordinate reads and keep source files read-only
- [x] create iOS `.minimalBookmark` data while access is granted
- [x] derive a stable hashed identity from resource ID, bookmark, or final fallback
- [x] decode Markdown strictly as UTF-8
- [x] reject malformed PDF data before creating a tab
- [x] render Markdown headings, paragraphs, lists, tasks, quotes, code, tables, and
  inline formatting as selectable content
- [x] render PDFs continuously with PDFKit
- [x] first/previous/next/last page and zoom in/out controls
- [x] loading overlay and typed open-error alert
- [x] close tabs by swipe/delete and release their registry claims
- [x] deterministic debug-only Markdown/PDF injection for UI tests
- [x] resolve bookmarks for reopen and add a capped/deduplicated Recent Documents list
- [x] register PDF/Markdown document types and handle external URL delivery once
- [x] accept supported file URL drag/drop in the workspace
- [x] activate the existing scene and tab when a cross-window duplicate is found
- [x] PDF outline and thumbnail navigation with invalid-index guards

### Phase 2: windows, search, restoration

- [x] one-shot open router for external URL delivery
- [x] multiple iPad windows with explicit New Window and Open in New Window actions
- [x] Markdown/PDF search with match counts, highlighting, and explicit navigation
- [x] versioned PDF page/scale and Markdown visible-character persistence hooks
- [ ] scene and tab restoration across relaunch

The search and reading-position slice is implemented and covered by unit tests on
the iPad simulator. Scene activation and explicit new-window routing are now
implemented and covered by coordinator tests plus a UI menu smoke test. Closing a
workspace releases all of its registry claims. PDF search is currently synchronous
through PDFKit; larger-document cancellation and async search belong to viewer
hardening. Relaunch restoration is the remaining Phase 2 implementation unit.

### Phase 3: viewer hardening

- responsive layouts
- keyboard, pointer, accessibility, Dynamic Type
- cancellation/performance
- integration fixtures and iPad UI tests
- privacy/security review

### Phase 4: Markdown editing

- source/split editor
- formatting assistance
- Save/Save As and external-change protection
- unsaved-close prompts

### Phase 5: PDF annotations/forms

- Pencil/touch markup and shapes
- form edit tracking
- undo/redo
- annotation list/report
- safe persistence

### Phase 6: AI

- provider/context core
- iPad assistant UI
- Keychain/local-network handling
- explicit remote consent
- streaming, cancellation, request-provenance, and safety tests

## 9. Automated testing requirements

The iPad project must add tests beyond the macOS baseline.

Unit coverage:

- document type and stable identity
- bookmark and security-scope behavior
- duplicate/open routing that activates the existing scene/tab
- workspace isolation
- Markdown parsing and Unicode search
- PDF index guards
- reading-state coding/migration/clamping
- no document content in metadata stores

Integration fixtures:

- structured Unicode Markdown
- searchable multi-page PDF
- PDF with outline
- PDF without outline
- malformed PDF

UI coverage:

- Markdown/PDF opening
- PDF navigation
- both search flows
- clearing search without page jump
- restoration after relaunch
- two independent windows
- second external open not changing the first window
- narrow/wide layout
- portrait/landscape
- accessibility identifiers and large text smoke tests

Do not automate only through the system document picker. Provide a test-only injection seam for deterministic UI tests and retain manual picker testing.

## 10. Known blockers and open decisions

Simulator blocker:

- resolved on 2026-07-21; iOS 26.5 and `FileViewer Test iPad` are available

Resolved:

- app display name: `FileViewer`
- product/target name: `FileViewerIpad`
- bundle identifier: `com.timetochilltoo.FileViewerIpad`
- neutral core currently lives in app-target folders, keeping Phase 0 simple

Open:

- Apple development team/signing choice for a physical-device build
- whether the neutral core should become a local Swift package after it grows

Neither blocks simulator-based Phase 2 work.

Known current limitations:

- Scene payload activation and explicit new-window routing are implemented for
  simulator-tested viewer flows. The app still needs relaunch-level scene/tab
  restoration, and scene-close behavior should receive a physical-device review.
- Search uses synchronous in-memory indexing for this first viewer slice; move
  large PDF indexing to an asynchronous, cancellable service during hardening.
- Persistence is versioned and wired into the readers, but relaunch restoration
  and scene/tab session restoration still need an end-to-end UI acceptance test.
- PDF fit-page, fit-width, and direct page-number entry remain.
- External-open document registration and bookmark reopen have automated coverage
  at the router/service level, but still need manual acceptance with real Files and
  iCloud provider documents on a physical iPad.
- The app has not been signed or run on a physical iPad.

## 11. Exact next steps for the next agent

1. Read this file and `docs/IPAD_ARCHITECTURE_AND_MIGRATION_PLAN.md`.
2. Inspect `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad` with read-only `git status`. The five documentation modifications listed in Section 2 are expected until the macOS agent commits them; do not clean or modify them.
3. Check `git status` and preserve any user/agent changes.
4. Implement versioned scene/tab session restoration across relaunch, using bookmark
   identities rather than serializing in-memory PDF/SwiftUI objects.
5. Add an end-to-end UI test for restoration and verify missing/stale bookmarks are
   skipped with a non-destructive message.
6. Add manual Files/iCloud acceptance checks with real Markdown and PDF fixtures on
   a physical iPad when signing is available.
7. Add/update this handoff after every meaningful implementation unit.
8. Run the full simulator test command before committing.
9. Commit and push coherent verified units under the configured Git identity.

Do not begin with PDF annotations, Markdown editing, forms, or AI. Do not copy the macOS project wholesale.

## 12. Latest build and test evidence

Command:

```bash
xcodebuild \
  -project FileViewerIpad.xcodeproj \
  -scheme FileViewerIpad \
  -destination 'platform=iOS Simulator,id=174A3DF4-AE79-42FF-A063-90ED2887FBD7' \
  -derivedDataPath /private/tmp/FileViewerIpadDerivedDataSceneFinal \
  test
```

Latest full-suite verification on 2026-08-10:

- `DocumentAccessRegistryTests`: 2 passed
- `DocumentAccessServiceTests`: 7 passed
- `MarkdownBlockParserTests`: 2 passed
- `OpenRequestRouterTests`: 1 passed
- `DocumentSearchIndexTests`: 3 passed
- `PDFReaderModelTests`: 3 passed
- `ReadingStateStoreTests`: 2 passed
- `RecentDocumentStoreTests`: 2 passed
- `WorkspaceModelTests`: 7 passed
- `WorkspaceSceneCoordinatorTests`: 4 passed
- `FileViewerIpadUITests`: 3 passed
- total: 33 unit tests and 3 UI tests passed, 0 failed
- Xcode result: `** TEST SUCCEEDED **`
- result bundle:
  `/tmp/FileViewerIpadDerivedDataSceneFinal/Logs/Test/Test-FileViewerIpad-2026.08.10_01-35-02-+0800.xcresult`

The expanded suite also opens the Markdown debug fixture, exposes the Window
Actions menu, and verifies both `New Window` and `Open in New Window` actions. The
scene coordinator tests verify that queued requests and activations are delivered
only to their target workspace. The unit-only follow-up after adding workspace
close cleanup passed 32 tests at:
`/tmp/FileViewerIpadDerivedDataScene3/Logs/Test/Test-FileViewerIpad-2026.08.10_01-32-33-+0800.xcresult`.

The two-page PDF UI fixture was also installed and visually inspected on
`FileViewer Test iPad`. Continuous pages, the bottom controls, and the navigation
toolbar fit correctly in the regular-width split view. The UI test opens the PDF
navigator and verifies its page-thumbnail and outline controls.

Non-blocking simulator output included an Apple runtime duplicate accessibility-class
warning and an LLDB version-store warning. Neither affected launch or test results.

## 13. Handoff maintenance standard

Update this document whenever any of these change:

- branch or baseline commit
- toolchain, SDK, simulator, or signing status
- project structure
- architecture decisions
- completed phase/feature
- build/test commands and results
- known bugs or blockers
- privacy/security behavior
- next exact work item

Every entry should distinguish:

- implemented and verified
- implemented but not verified
- planned only
- deferred

Never describe a planned capability as working. The checked Phase 0/Phase 1 items
and the checked Phase 2 search/position/scene-routing items above are implemented
and verified at the stated level; relaunch session restoration and later phases
remain planned.
