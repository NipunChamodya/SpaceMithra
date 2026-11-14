# SpaceMithra

A free, offline, native macOS storage explorer built with Swift 6, SwiftUI, Foundation, CryptoKit and SQLite. MIT licensed, with no third-party dependencies, login, ads, telemetry, or file uploads.

**Status: development preview, not yet a production release.** The app performs real filesystem scans and explicit Move-to-Trash operations. Review the safety limitations before using cleanup. No screenshot/reference asset was included with the request; the UI uses original native components.

## Build and run

Requires macOS 13+ and Xcode with Swift 6 (tested with Xcode 27.2 / Swift 6.4.2). Open `SpaceMithra.xcodeproj`, select the SpaceMithra scheme and run. No paid developer account is required for local builds. Select your own signing configuration if Xcode requests one.

```sh
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The app is at `build/Build/Products/Debug/SpaceMithra.app`. Development builds are not notarized. Do not disable Gatekeeper globally. Build locally in Xcode or sign a release with your own identity.

## What works

- Beginner-first welcome, Scan My Mac, read-only animated progress with Reduce Motion, and a capacity/coverage dashboard.
- Application overview cards with separate bundle, recognized cache and attributable data sizes; Node.js, Python and other recognized developer locations.
- User-initiated recursive scans, pause/resume/cancel, streamed SQLite storage, bounded pages, folder totals, hard-link-aware aggregate estimates, unreadable-item counts.
- Folder columns, breadcrumbs, search, category/name/size/date sorting, hidden files, file metadata, Finder reveal and Quick Look.
- Biggest-files filters, recognized cache owners grouped by discovered paths, developer storage inspection, deterministic risk explanations.
- Individual Keep/Clean/Protect, persistent exact-path and descendant rules, 24-hour protection, explicit review queue spanning scans, read-only preflight and immutable confirmation snapshots and cancellable preflight.
- Identity revalidation, durable per-operation journal, Move to Trash without permanent-delete fallback, batch progress and safe cancellation, recovery with conflict checks and history grouped by cleanup session, with timestamped recovery availability and conflict checks.
- SQLite-backed resumable staged SHA-256 duplicate detection with bounded batches, descriptor-validated reads, partial-error reporting, and no automatic duplicate selection.
- Authoritative startup-disk capacity independent of scans, exclusive logical category totals, interactive bounded treemap, and local scan totals over time.
- Seven-language string catalog, Sinhala default, Arabic RTL, standard keyboard controls and native accessibility semantics.

## Safety

Scanning is read-only. Cleaning only acts on explicitly confirmed regular file records. Folders, symlinks, packages and package contents, hard links, cloud-managed items, system paths, known application databases, unrecognized user-Library state, credentials, simulator data, Docker state and protected items are blocked. Unknown files are never described as junk or low risk. A recognized cache still requires review and may be in use. Close its owning app yourself.

Moving to Trash **does not reclaim disk space**. SpaceMithra never permanently deletes files, empties Trash, invokes privileged helpers, or runs cleanup shell commands. Trash and restore operations are not atomic with identity checks; see [the safety model](docs/filesystem-safety.md).

## Tests

All mutating tests use repository-local `.test-fixtures` and an injected fixture-only Trash. The explicit test flag is mandatory. No test calls SystemTrash against user files.

```sh
SPACEMITHRA_TEST_MODE=1 swift test
python3 scripts/check_localization.py
python3 scripts/prepare_ui_fixture.py
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -destination 'platform=macOS' -derivedDataPath build-overhaul-ui \
  SPACEMITHRA_BUNDLE_ID=org.spacemithra.overhaul-ui CODE_SIGN_IDENTITY=- test
```

See [test results and measurements](docs/testing.md), [architecture and checklist](docs/architecture.md), [cleanup rules](docs/cleanup-rules.md), and [localization](docs/localization.md).

## Current limits / release gates

- Draft translations require fluent-speaker review. Filesystem/system errors may use the operating system’s language.
- A fresh scan replaces the previous browsable catalog. The queue and recovery journal retain their file records. Rescans enumerate the tree and reuse metadata for unchanged identities; filesystem-event monitoring is not implemented.
- Duplicate detection has no fixed candidate cutoff: a disk-backed work queue groups by size, samples content, then compares full SHA-256 hashes. Results page 200 groups and 100 copies at a time. Changed/unreadable files are reported and skipped; issue details are capped at 200. It does not identify APFS shared extents, visually similar images, or cloud-only content.
- The treemap shows bounded current-page data; dashboard category totals use the complete current scan catalog. Both explicitly disclose partial coverage. Scan history totals are not comparable when roots differ.
- No automatic tool commands, folder cleanup, active-use detection, clone accounting, or post-Trash free-space claims. Developer storage paths are inspected, not forcibly removed.
- Foundation path APIs cannot provide a race-free inode-bound Trash transaction. A hostile process swapping paths during the final call remains a limitation.
- macOS 13 runtime, Intel runtime, large real-volume memory, VoiceOver, Quick Look, and actual system Trash need additional manual acceptance testing. A universal binary build alone does not validate both runtimes.
- Signed/notarized public distribution and human safety audit remain release gates.

## Release package

Run `scripts/release.sh build-overhaul` for version 0.2.0 without replacing older build directories. It builds an Apple Silicon + Intel app, signs it locally ad hoc, and creates a ZIP plus SHA-256 checksum under `dist/`. Ad hoc signing is for local testing and is not Developer ID notarization. Public releases should be independently reviewed, Developer ID signed and notarized when that signing infrastructure is available. See [release instructions](docs/releasing.md).
