# FileViewer for iPad — Architecture and Migration Plan

Last updated: 2026-07-21  
Status: Planning complete; Phase 0 foundation implemented and simulator-tested  
Writable workspace: `/Users/patrickshi/Documents/Codex/FileViewer_iPad`  
Read-only macOS reference: `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad`

## 1. Purpose and scope

This project will port the useful parts of the native macOS FileViewer into a native iPad application for reading Markdown and PDF documents. The first delivery is a reading product, not a broad editor.

The implementation order is intentionally:

1. PDF and Markdown viewing
2. document opening and persistent file access
3. multiple iPad windows
4. document search
5. reading-position restoration
6. responsive iPad UI, reliability, security, and automated tests
7. Markdown editing
8. PDF annotations and forms
9. AI integration

Editing, annotations, forms, and AI are explicitly deferred. Their future requirements influence boundaries in the architecture, but they must not expand the first viewer milestones.

## 2. Compatibility decision

- Deployment target: **iPadOS 26.0**
- Expected compatibility: **iPadOS 26.x and later**, subject to normal validation when a later major iPadOS release becomes available
- Device family: iPad only
- iPhone support: not planned
- Mac Catalyst: not planned
- visionOS: not planned
- Back-deployment below iPadOS 26: not required
- Development baseline discovered on 2026-07-20:
  - Xcode 26.6 (build 17F113)
  - Swift 6.3.3
  - iOS/iPadOS device and simulator SDK 26.5

Simulator readiness was verified on 2026-07-21:

- iOS 26.5 simulator runtime `(23F77)` is installed and eligible in Xcode 26.6.
- Standard iPad Pro, iPad Air, iPad mini, and base iPad simulators are available.
- A dedicated `FileViewer Test iPad` simulator is available at UDID
  `174A3DF4-AE79-42FF-A063-90ED2887FBD7`.

The project should set `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `TARGETED_DEVICE_FAMILY = 2`. Since compatibility below iPadOS 26 is not a goal, use current SwiftUI scene, observation, navigation, and toolbar APIs directly when they materially simplify the implementation.

## 3. Reference baseline and non-modification rule

The macOS source was audited from:

- directory: `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad`
- branch: `feature/ai-assistant`
- commit: `834c98602b20ac7a78585e1168873851359333ae`
- commit date: 2026-07-20
- commit subject: `Clarify AI assistant actions`

The reference worktree was clean during the initial source audit. On 2026-07-21, the documentation was refreshed from uncommitted read-only worktree updates to:

- `HANDOFF.md`
- `README.md`
- `docs/ai-assistant-specification.md`
- `docs/mvp-task-list.md`
- `docs/requirements-and-specification.md`

The Swift source and tests were unchanged by that documentation refresh. The updated documents establish the current behavior where reopening an already-open file brings its existing writable instance forward, and clarify that the AI implementation already supports LM Studio, Ollama, custom OpenAI-compatible servers, and OpenAI.

`R_FileViewer_ipad` is immutable reference material. No build, formatter, package-resolution, test, or Git command that can write should be run in that directory. Read-only commands such as `sed`, `rg`, `find`, `git status`, and `git log` are permitted. All new files, generated output, project metadata, tests, and documentation belong in `/Users/patrickshi/Documents/Codex/FileViewer_iPad`.

## 4. macOS source audit

### 4.1 Classification definitions

- **Platform-neutral**: can move with no meaningful UI-framework change, after decoupling it from a monolithic file if necessary.
- **Conditionally reusable**: core logic or SwiftUI structure is useful, but adapters, imports, colors, dialogs, or lifecycle code must be replaced or isolated using protocols and, where sharing one file is valuable, `#if os(macOS)` / `#if os(iOS)`.
- **AppKit-specific**: built around `NSApplication`, `NSWindow`, `NSViewRepresentable`, `NSTextView`, `NSEvent`, macOS panels, or macOS window ownership. Reimplement for iPad rather than mechanically translating names.

There is currently no conditional compilation in the macOS Swift source. There are also no UIKit implementations to carry over.

### 4.2 File-by-file audit

| Reference file | Classification | Reuse decision for iPad |
|---|---|---|
| `AIAssistant.swift` | Mostly platform-neutral, deferred | Preserve the implemented provider protocol and profiles for LM Studio, Ollama, custom OpenAI-compatible servers, and OpenAI; also preserve context chunks, Markdown/PDF extraction, retrieval, exports, streaming, remote-consent enforcement, reasoning-tag filtering, request provenance, and Keychain design. Do not include it in the viewer MVP. Split document-independent AI types from UI/session orchestration before porting. Validate iPad Keychain accessibility and local-network behavior when enabled. |
| `AIAssistantPanel.swift` | Conditionally reusable, deferred | SwiftUI panel concepts and provider settings are reusable later. `AIComposerTextEditor`, `SendingTextView`, and `NSViewRepresentable` are AppKit-specific and require `UITextView`/`UIViewRepresentable` or a native SwiftUI replacement preserving Return-to-send and Shift-Return behavior. |
| `AppCommands.swift` | Conditionally reusable | Command names and enablement rules are useful. macOS menu structure and focused-window fallback should not be copied. Build iPad toolbar/menu commands around focused scene state and keyboard shortcuts; omit annotation/edit/AI commands until their phases. |
| `ContentView.swift` | Conditionally reusable, substantial rewrite | Reuse the conceptual shell—sidebar, document area, tabs, status, search, and type-specific toolbar. Replace AppKit import, `SearchTextField`, `WindowRegistrationView`, macOS window registry integration, fixed desktop sizing, and notification-heavy routing. Use iPad-native search, scene state, size classes, and toolbar placement. |
| `DocumentModel.swift` | Mixed; extract neutral core, do not port monolithically | Reuse enums and value models for document kind, per-tab search, PDF page/scale, Markdown visible location, file-version checks, heading extraction, outline extraction, state coding, and safe duplicate detection. AppKit panels, alerts, printing, `NSTextView` tracking, `NSColor`, `NSView` traversal, window-session frames, and annotation UI state are platform-specific or deferred. Split this 2,628-line file into focused models/services. |
| `FileViewerApp.swift` | AppKit-specific | Replace `NSApplicationDelegateAdaptor` and termination handling with an iPad SwiftUI `App`, `WindowGroup`, scene phase handling, open-URL routing, and state restoration. |
| `FileViewerWindowRegistry.swift` | AppKit-specific | Do not port `NSWindow` retention, delegates, frame strings, or manual window creation. Preserve only the behavioral lessons: a file-open event must be consumed once, scene models must not be global, an empty scene may accept the first file, and duplicate writable instances need protection. Rebuild with SwiftUI scene APIs and an app-level routing actor. |
| `MarkdownSyntaxHelp.swift` | Conditionally reusable, later editing phase | The SwiftUI help content can be reused. Replace the singleton `NSWindow` presenter and `NSHostingView` with an iPad sheet, popover, or navigation destination. Not required for read-only viewer MVP. |
| `MarkdownWorkspace.swift` | Mixed | Reuse parsing and rendering ideas: `MarkdownPreviewBlock`, block parsing, attributed inline Markdown, underline preprocessing, table/task-list logic, UTF-16 search range math, and visible-character restoration. Replace both `NSViewRepresentable` text views, `NSTextView`, `NSScrollView`, native `NSMenu`, AppKit coordinate conversion, source editing, and desktop split layout. The viewer phase needs only a read-only Markdown renderer plus search and restoration. |
| `PDFWorkspace.swift` | Mixed with a large AppKit-specific surface | Reuse PDFKit document/search/page/outline concepts, invalid-index guards, explicit search-navigation request IDs, and state synchronization lessons. Implement viewing with `PDFView` in `UIViewRepresentable`. Replace all `NSViewRepresentable`, `NSEvent`, `NSColor`, `NSAlert`, overlays, mouse handling, AppKit form notifications, and thumbnail scroll wrappers. Annotation/form sections are deferred and should not be compiled into the first phases. |
| `SidebarView.swift` | Mostly reusable SwiftUI structure | Reuse recent/contents/pages concepts and PDF outline rows. Redesign for `NavigationSplitView`, touch targets, compact widths, iPad sidebar visibility, and iPad-native thumbnail presentation. Exclude Notes/annotations until the annotation phase. |

### 4.3 Tests and non-source assets

| Reference item | Decision |
|---|---|
| `DocumentSafetyTests.swift` | Port Markdown dirty-state and file-version tests when their types exist. Adapt duplicate-open tests to the new resource identity and scene routing rules. Keep platform dialogs out of unit tests. |
| `AIAssistantTests.swift` | Most chunking, provenance, export, safe-default, remote-host rejection, and hidden-reasoning tests are portable, but defer them with AI. |
| `Package.swift` | Do not reuse as the main iPad packaging approach. It targets macOS 26 and an executable Swift package. Use an Xcode iPad application project, optionally with a local Swift package for platform-neutral core code if that reduces target coupling. |
| `src/`, Vite files, `dist/` | Historical prototype; not part of the port. |
| macOS packaging scripts | Not reusable for iPad signing, provisioning, installation, or archive workflows. |

### 4.4 High-value algorithms to extract rather than rewrite

- Markdown extension detection
- file-version metadata comparison before later overwrite operations
- Markdown heading extraction
- lightweight Markdown block parsing
- Markdown table and task-list parsing
- UTF-16 range handling for search and future formatting
- PDF outline extraction, including direct destinations and `PDFActionGoTo`
- defensive `NSNotFound`/invalid PDF page-index guards
- per-tab search state and explicit navigation request IDs
- PDF page and scale persistence
- Markdown first-visible-character persistence, with pixel offset only as fallback
- AI context chunking, source provenance, endpoint validation, and disclosure behavior in the later AI phase

### 4.5 macOS behavior that must not be copied

- A singleton document/workspace model shared by all windows
- a global file-open notification observed by every window
- manually retained `NSWindow` objects
- desktop window frame persistence
- fixed 320-point sidebar geometry as the primary responsiveness solution
- synchronously scanning all PDF text on the main actor for large documents
- depending on filesystem paths alone for persistent access to Files/iCloud documents
- copying annotation and editing complexity into the viewer milestone

## 5. Proposed iPad architecture

## 5.1 Project structure

Use an Xcode iPad app project with app, unit-test, and UI-test targets:

```text
FileViewerIpad/
├── App/
│   ├── FileViewerIpadApp.swift
│   ├── AppEnvironment.swift
│   └── OpenRequestRouter.swift
├── Core/
│   ├── Models/
│   │   ├── DocumentKind.swift
│   │   ├── DocumentIdentity.swift
│   │   ├── DocumentTab.swift
│   │   ├── ReadingState.swift
│   │   └── RecentDocument.swift
│   ├── FileAccess/
│   │   ├── DocumentAccessService.swift
│   │   ├── SecurityScopedResource.swift
│   │   └── BookmarkStore.swift
│   ├── Persistence/
│   │   ├── ReadingStateStore.swift
│   │   ├── RecentDocumentStore.swift
│   │   └── SceneSessionStore.swift
│   └── Search/
│       ├── SearchQuery.swift
│       └── SearchNavigationState.swift
├── Features/
│   ├── Workspace/
│   │   ├── WorkspaceModel.swift
│   │   ├── WorkspaceView.swift
│   │   ├── TabStrip.swift
│   │   └── DocumentSidebar.swift
│   ├── Markdown/
│   │   ├── MarkdownDocumentLoader.swift
│   │   ├── MarkdownBlockParser.swift
│   │   ├── MarkdownReaderView.swift
│   │   ├── MarkdownTextView.swift
│   │   └── MarkdownSearchService.swift
│   └── PDF/
│       ├── PDFDocumentLoader.swift
│       ├── PDFReaderView.swift
│       ├── PDFViewAdapter.swift
│       ├── PDFSearchService.swift
│       └── PDFSidebarContent.swift
├── Resources/
├── FileViewerIpadTests/
└── FileViewerIpadUITests/
```

The exact groups may change during scaffolding, but dependencies must point inward: UI depends on models and protocols; core services do not depend on SwiftUI views.

## 5.2 State ownership

Use three levels of state:

1. **App environment**
   - long-lived service objects
   - bookmark, recent, and reading-state stores
   - `OpenRequestRouter`
   - `DocumentAccessRegistry` actor
   - never owns the selected document for every window

2. **Scene/workspace model**
   - one instance per iPad window
   - tabs, selected tab, sidebar visibility, search presentation
   - scene restoration identifier
   - accepts a routed open request exactly once

3. **Document-tab state**
   - loaded Markdown or `PDFDocument`
   - stable `DocumentIdentity`
   - search query/index/count/request ID
   - PDF page/scale
   - Markdown visible UTF-16 character location and fallback offset
   - loading/error state

Do not put document-specific state directly on the global app environment. This preserves the macOS lesson that each window needs independent selected-document and UI state.

## 5.3 Document representation

Suggested core types:

```swift
enum DocumentKind: String, Codable, Sendable {
    case markdown
    case pdf
}

struct DocumentIdentity: Hashable, Codable, Sendable {
    let persistentID: String
    let displayName: String
}

enum LoadedDocument {
    case markdown(MarkdownReadDocument)
    case pdf(PDFReadDocument)
}
```

`DocumentIdentity` must not be only `url.path`. Derive a stable identifier from bookmark metadata and, when available, file resource identifiers. Handle renamed or moved Files/iCloud items by resolving their bookmark and refreshing stale bookmark data.

Keep `PDFDocument` and other non-Sendable framework objects on the main actor or behind a deliberately isolated wrapper. Perform plain-text parsing and persistence encoding off the main actor where safe.

## 5.4 File opening and security-scoped access

Supported opening paths:

- SwiftUI `.fileImporter` for PDF, `.md`, and `.markdown`
- Files app / Share sheet / system “Open in” through scene URL handling
- drag and drop of supported file URLs
- recent documents backed by security-scoped bookmarks
- a New Window / Open in New Window action

Required access flow:

1. Receive URL.
2. Validate the extension/UTType before loading.
3. Begin security-scoped access when required.
4. Coordinate the read using `NSFileCoordinator` where appropriate.
5. Create or refresh a security-scoped bookmark for recents/restoration.
6. Determine stable document identity.
7. Route to the intended scene once.
8. Load with a typed loader.
9. Balance every successful `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()`.

Use a small `SecurityScopedResource` lifetime wrapper so balancing is testable. Do not keep arbitrary URL access alive forever. PDFKit may need access for the lifetime of the loaded PDF; the wrapper should make that lifetime explicit in the tab.

The viewer phase is read-only. It must never write into a source document. Later editing must add external-change detection and coordinated atomic replacement before enabling Save.

## 5.5 Multiple windows and tabs

Use SwiftUI `WindowGroup` with a Codable, hashable scene payload and `openWindow(value:)`.

Behavior:

- A workspace scene may contain multiple tabs.
- Opening from inside a populated scene defaults to a new tab.
- “Open in New Window” explicitly creates another scene.
- A system external-open request reuses an empty scene when possible; otherwise it creates one new scene.
- The request router marks each external request as consumed so all live scenes cannot react to the same URL.
- Each scene owns a distinct `WorkspaceModel`.
- The app-level access registry knows which stable identities are open and where.
- Reopening a document already present in any scene activates its existing tab/window instead of creating another live document instance.
- Apply this one-instance-per-identity rule from the first viewer phase. It matches the current macOS safety behavior, avoids confusing restoration/search state, and prevents a later migration hazard when writing is enabled.
- A future explicit “Open Read-Only Copy” feature may relax this rule, but ordinary open, recent, drag/drop, and restoration flows must not create duplicates.

Scene restoration stores identifiers/bookmarks and tab state, not in-memory framework objects. Missing or inaccessible files are skipped with a clear non-destructive message.

## 5.6 Markdown reader

Phase-one Markdown is read-only.

Implementation:

- Load UTF-8 with a clear encoding/read error.
- Extract headings for Contents.
- Port the block parser for headings, paragraphs, lists, task lists, quotes, fenced code, and basic tables.
- Use attributed inline Markdown for bold, italic, links, code, and strikethrough.
- Preserve the `<u>...</u>` convenience only as safe display formatting.
- Prefer a read-only `UITextView` adapter when exact search highlighting, selection, link interaction, and visible-character restoration require TextKit access.
- Do not load arbitrary remote images or execute embedded HTML/JavaScript in the first phases.
- If local images are added later, resolve only through explicitly granted file access.

Search:

- debounce input
- compute case-insensitive UTF-16 ranges away from the main actor
- publish results back to the tab
- highlight all matches and distinguish the active match
- navigate only on an explicit request-ID change
- restore by first visible UTF-16 character location; use scroll offset only as fallback

Editing controls, source/split mode, formatting, selection-to-source mapping, Save, and close prompts remain out of scope until the editing phase.

## 5.7 PDF reader

Use PDFKit through `UIViewRepresentable`.

Initial view behavior:

- continuous vertical display
- auto-scale initial content
- page count and current page synchronization
- first/previous/next/last and page jump
- zoom in/out, fit page, and fit width
- text selection and copy
- thumbnails and outline navigation
- graceful handling of corrupt, encrypted, or unsupported PDFs

Defensive rules carried from macOS:

- Treat `PDFDocument.index(for:) == NSNotFound` as invalid.
- Validate indexes against `0..<pageCount` before adding one or navigating.
- Ignore callbacks from a stale `PDFDocument` identity.
- Avoid mutating SwiftUI/Observation state synchronously from representable update callbacks when that causes update recursion.

Search:

- prefer PDFKit’s asynchronous search/delegate path for larger PDFs
- cancel stale searches when query, tab, or document changes
- highlight without forcing navigation
- issue a separate explicit navigation request when query changes or the user presses next/previous
- clearing search removes highlights without moving the reading position

Restoration stores a one-based user-facing page, PDF scale, and, if reliable on iPad PDFKit, a finer visible offset. Always clamp restored values to the current document.

Annotations, form-dirty detection, drawing overlays, PDF save, and annotation undo stacks are not included in the first PDF reader implementation.

## 5.8 Responsive interface

Use iPad-native adaptive layout rather than desktop fixed geometry.

- `NavigationSplitView` for sidebar plus detail at regular widths
- collapsible/overlay sidebar behavior at compact widths
- tab strip that can horizontally scroll or collapse into a document picker
- toolbar groups that adapt using `ViewThatFits`, menus, and size classes
- touch targets at least 44x44 points
- keyboard shortcuts for open, search, page navigation, zoom, sidebar, and new window
- pointer and trackpad affordances without making hover mandatory
- support portrait, landscape, Split View, Slide Over where available, and Stage Manager window resizing
- keep the document readable with Dynamic Type, VoiceOver labels, high contrast, and system appearance
- use safe areas and keyboard avoidance

Required layout test widths should include narrow split-screen, portrait, landscape, and a resizable Stage Manager-style window. No PDF page may be covered by the sidebar, and no primary navigation control may become unreachable.

## 5.9 Persistence

Use separate stores behind protocols:

- `BookmarkStore`: security-scoped bookmark data and display metadata
- `RecentDocumentStore`: recent order and timestamps
- `ReadingStateStore`: per-document PDF/Markdown position and selected viewing options
- `SceneSessionStore`: tabs and selection per scene

UserDefaults is acceptable for small encoded records. Use Application Support files if records grow. Never store document contents, AI conversations, or credentials in UserDefaults.

Persistence keys should be versioned from the beginning. Writes should be debounced and occur at natural points:

- page/scale settles
- Markdown scrolling settles
- selected tab changes
- scene moves to background
- tab closes
- scene closes

Restoration failure must not block opening the app.

## 5.10 Error model

Use typed service errors converted to user-facing messages at the view-model boundary:

- unsupported type
- permission denied or stale bookmark
- missing/moved file
- unreadable Markdown/encoding
- invalid/corrupt PDF
- encrypted PDF requiring password
- canceled operation

Cancellation is not an error banner. Keep technical details available for debug logging without displaying paths or document content unnecessarily.

## 6. Security and privacy requirements

Preserve and strengthen the local-first behavior:

- No network requests in viewer, search, or restoration phases.
- Never upload document content implicitly.
- Treat document text and PDF metadata as sensitive.
- Store persistent access as security-scoped bookmarks.
- Store future API keys only in Keychain, one entry per provider profile.
- Do not log document text, selected text, API keys, bookmark data, or full sensitive paths.
- Do not execute scripts or active HTML from Markdown.
- Do not fetch remote Markdown resources automatically.
- Open external links through explicit user action.
- Treat PDFs and Markdown as untrusted input; validate indexes and sizes and avoid unbounded synchronous work.
- Cap recent/session records and discard invalid entries safely.

When AI is implemented later:

- local endpoints remain the default for LM Studio/Ollama
- preserve the implemented provider profiles for LM Studio, Ollama, custom OpenAI-compatible servers, and OpenAI
- remote endpoints require explicit “allow this provider to receive document text” consent
- the UI identifies the remote host before sending
- extraction/retrieval stays on device
- a request occurs only after an explicit Send/Summarize/Translate action
- label exact supplied chunks as **request provenance**, not citations; PDF page labels may navigate, while Markdown heading labels remain informational until reliable navigation exists
- exclude PDF form values from AI context by default because form contents may be more sensitive than ordinary page text
- reasoning inside `<think>...</think>` remains hidden and excluded from history/export
- AI receives no file mutation, annotation, deletion, or shell tools
- conversation persistence remains opt-in; the macOS baseline is memory-only
- iPad Local Network privacy and ATS configuration must be narrowly scoped and documented

## 7. Automated test strategy

## 7.1 Unit tests

- Markdown type recognition, including case
- stable identity and duplicate-open logic
- security-scope lifetime balancing using a fake resource
- bookmark-store encoding, stale refresh, and missing-file handling
- Markdown heading/block/table/task parsing
- Markdown UTF-16 search ranges, Unicode, empty query, and overlapping behavior
- PDF index clamping and invalid `NSNotFound` handling
- reading-state coding, version migration, clamping, and debounce
- external open request consumed by exactly one scene
- scene/tab isolation
- no document content persisted in metadata stores

## 7.2 Integration tests

Include small checked-in fixtures with no private data:

- structured Markdown with Unicode, headings, tables, tasks, code, and repeated search phrases
- multi-page searchable PDF
- PDF with outline
- PDF without outline
- malformed or truncated PDF
- optional encrypted PDF fixture if licensing permits

Verify loader, outline, search, page restoration, and cancellation behavior against fixtures.

## 7.3 UI tests on iPad simulator

- open Markdown through a test import seam
- open PDF and navigate pages
- search Markdown and PDF; next/previous updates current result
- clear PDF search without jumping to page one
- reopen and restore reading position
- create two app windows and verify independent selected documents
- open a second external document without changing the first window
- sidebar and controls remain reachable at narrow and wide sizes
- portrait/landscape and Dynamic Type smoke tests
- VoiceOver identifiers exist for icon-only controls

Avoid making the system document picker the only automation path; inject test documents through launch arguments or a test-only import service while retaining at least one manual picker acceptance test.

## 7.4 Build and test commands

The exact scheme will be set during scaffolding. Expected form:

```bash
xcodebuild \
  -project FileViewerIpad.xcodeproj \
  -scheme FileViewerIpad \
  -destination 'platform=iOS Simulator,name=FileViewer Test iPad,OS=26.5' \
  test
```

The Phase 0 project passed this command on 2026-07-21 using the dedicated simulator:

- 4 unit tests passed
- 1 UI launch test passed
- 0 failures
- result bundle:
  `/private/tmp/FileViewerIpadDerivedData/Logs/Test/Test-FileViewerIpad-2026.07.21_02-15-52-+0800.xcresult`

The result bundle is temporary and is not a project artifact. Also perform device builds with the personal signing team once configured.

## 8. Migration phases and exit criteria

### Phase 0 — Project and foundations

- [x] Create iPad-only Xcode project, unit tests, UI tests, and deployment settings.
- [x] Add core document types and service protocol seams.
- [x] Add immutable-reference warning to project documentation.
- [x] Establish generation/build/test commands.
- [x] Add workspace-isolation and duplicate-document-registry seed tests.
- [x] Verify the empty workspace through an iPad UI launch test.

Exit achieved on 2026-07-21: the app, unit-test bundle, and UI-test bundle built for
the iPadOS 26.5 simulator, and all five seed tests passed.

### Phase 1 — Secure opening and basic readers

- File importer, URL routing, drag/drop, bookmark creation, recent documents
- Markdown read-only renderer
- PDFKit read-only renderer
- per-scene workspace with tabs
- basic page navigation and outline/thumbnails
- clear loading and error states

Exit: supported files open from Files and render without writes; two documents retain independent tab state.

### Phase 2 — Multiple windows, search, and restoration

- one-shot external-open router
- new-window/open-in-new-window flows
- Markdown and PDF search with explicit navigation requests
- page/zoom and visible-character persistence
- scene/tab restoration from bookmarks

Exit: two iPad windows remain independent; search does not pull the user back after manual scrolling; reading position survives relaunch.

### Phase 3 — Responsive, accessible, and hardened viewer

- all adaptive layouts
- keyboard/pointer support
- accessibility labels and Dynamic Type
- performance/cancellation work
- fixture integration tests and iPad UI tests
- privacy/security review

Exit: prioritized viewer workflows pass automated tests and manual iPad acceptance checks.

### Phase 4 — Markdown editing

- source and split modes
- `UITextView` editing bridge
- formatting assistance and syntax help
- external-change detection
- coordinated atomic Save/Save As
- unsaved-close behavior

Exit: edits are reliable and never overwrite an externally changed file silently.

### Phase 5 — PDF annotations and forms

- text markup, notes, shapes, ink
- touch/Pencil interactions
- annotation list and reports
- form-dirty detection
- safe Save Copy first; atomic save policy
- iPad-specific undo/redo and gesture tests

Exit: annotation and form changes persist without corrupting source PDFs.

### Phase 6 — AI

- port platform-neutral provider/context code
- iPad-native assistant UI
- Keychain and local-network permissions
- explicit remote transfer consent
- streaming/cancellation/request-provenance tests
- large-document extraction moved off the main actor

Exit: no content leaves the device without explicit action and consent; provider secrets never enter logs or UserDefaults.

## 9. First implementation slice — completed

The first slice was completed without copying the macOS `DocumentModel.swift`:

1. Create the Xcode iPad app and test targets.
2. Set iPad-only device family and iPadOS 26.0 deployment.
3. Add `DocumentKind`, `DocumentIdentity`, and reading-state value types.
4. Add file-access/bookmark protocols with fakes.
5. Add an empty per-scene `WorkspaceModel`.
6. Add one unit test proving two workspace models do not share selected-document state.
7. Build and test before introducing PDFKit or Markdown rendering.

This provides a verified foundation for the highest-risk platform differences:
security-scoped files and multi-window state ownership. The next implementation unit
is Phase 1 secure opening and basic read-only Markdown/PDF readers.

## 10. Decisions deliberately deferred

- Apple development team/provisioning profile
- whether platform-neutral code lives in the app target or a local Swift package
- richer GitHub-Flavored-Markdown library versus the existing custom parser
- full PDF visible-offset restoration beyond page and scale
- conversation persistence for AI

The Phase 0 identifiers are:

- display name: `FileViewer`
- product/target name: `FileViewerIpad`
- bundle identifier: `com.timetochilltoo.FileViewerIpad`

The remaining decisions do not block simulator work. A signing team must be selected
before a physical-device build.
