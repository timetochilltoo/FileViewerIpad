# FileViewer iPad agent guidance

## Scope and canonical handoff

- Work only in this repository: `/Users/patrickshi/Documents/Codex/FileViewer_iPad`.
- The canonical continuation document is [`HANDOFF.md`](/Users/patrickshi/Documents/Codex/FileViewer_iPad/HANDOFF.md). Read its current resume and constraints before implementation; do not copy its historical log into this file.
- Keep stable setup and test commands here/`README.md`; keep session-specific progress, blockers, and next actions in `HANDOFF.md`.

## Project facts

- Native SwiftUI iPad app, minimum iPadOS 26.0; current validation uses Xcode 26.6, Swift 6, and the iOS 26.5 simulator runtime.
- `project.yml` is the source of truth for targets and build settings. Run `xcodegen generate` after changing it; do not make unexplained project-file-only edits.
- Product identity is `com.timetochilltoo.FileViewerIpad` / `FileViewer`.
- Primary source areas are `FileViewerIpad/App`, `Core`, and `Features`; unit tests are in `FileViewerIpadTests`, UI tests in `FileViewerIpadUITests`.

## Build and test

Use the documented simulator destination and incremental build products:

```bash
xcodegen generate  # only when project.yml changed

xcodebuild \
  -project FileViewerIpad.xcodeproj \
  -scheme FileViewerIpad \
  -destination 'platform=iOS Simulator,name=FileViewer Test iPad,OS=26.5' \
  test
```

For focused iteration, append one of these flags before `test`:

```bash
-only-testing:FileViewerIpadTests
-only-testing:FileViewerIpadUITests/FileViewerIpadUITests/testCompactAccessibilityLayoutKeepsPrimaryPDFControlsReachable
```

Prefer incremental, native-architecture builds and save verbose logs when diagnosing failures. Do not clean derived data or rerun an unchanged full suite unless failure evidence warrants it. Treat CoreSimulatorService/device-discovery failures as environment limitations, not source failures, and record the exact scope in `HANDOFF.md`.

## Safety and product constraints

- `/Users/patrickshi/Documents/Codex/R_FileViewer_ipad` is immutable reference material. Never edit, generate, format, build, test, resolve packages, or run Git operations there; never copy generated output from it.
- Preserve unrelated working-tree changes. Never force-push, reset, checkout away changes, replace the verified `origin`, or change bundle/executable identity without explicit authorization.
- The viewer is read-only in current phases: preserve security-scoped access balancing, bookmark behavior, and local-first privacy. Do not add implicit uploads, credentials, API keys, or sensitive document contents to logs/UserDefaults.
- Keep editing, PDF annotations/forms, and AI integration out of viewer changes unless explicitly requested; add iPad-specific tests for new behavior.

## Handoff and checkpoints

- After a meaningful coherent change, update the current-resume portion of [`HANDOFF.md`](HANDOFF.md) with changed files, exact verification scope/result, artifact path if any, blockers, and the next action. Do not duplicate the full project history here.
- For Git checkpoints, use author `timetochilltoo <152804118+timetochilltoo@users.noreply.github.com>` and the existing verified `origin` when push is authorized.
