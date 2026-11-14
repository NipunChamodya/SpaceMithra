# Validation report

Recorded 2026-11-14 on the available Apple Silicon host running macOS 26.6.2, using Xcode 27.2 (27B52), Swift 6.4.2 and the macOS 27.2 SDK. Deployment target is macOS 13.0. This is a development-preview validation report, not production certification.

## Executed checks

| Check | Result |
|---|---|
| Native Debug build | Passed during implementation |
| Final universal Release build | Passed, arm64 + x86_64 |
| Core + presentation XCTest suite | 28 tests passed, 0 failures, about 2.60 seconds |
| Localization coverage | 159 keys × 7 languages; dynamic key families and literal UI keys checked |
| Localization fallback | Tested using an isolated synthetic bundle with a missing Sinhala key and unsupported locale |
| Local signature verification | Ad hoc signature verifies; not Developer ID notarized |
| ZIP checksum | SHA-256 verified after packaging |
| Real app startup smoke | Visible window + initialized isolated database confirmed; no scan or cleanup |
| Native UI automation | Blocked by host automation initialization timeout; no UI-test success claimed |

Tests cover recursion, directory totals, pagination, symlink cycles and ancestor swaps, hard-link accounting, package protection even when scanning from inside a package, unknown risk, exact protection boundaries/expiry, file changes, Trash failures, empty approved lists, partial cleanup, recovery conflicts and tampering, persisted rules/trends, SHA-256 duplicates, cancellation, unreadable directories, corrupt SQLite, incremental metadata reuse/removal, duplicate keeper enforcement from shared presentation logic, selection rejection while scanning, Library-state rejection, and invalid/nonfinite numeric filter input.

Mutating tests require `SPACEMITHRA_TEST_MODE=1`. They create UUID-isolated `.test-fixtures` beneath this repository. An injected fixture Trash refuses all paths outside that fixture. It moves files within the fixture and does not call macOS SystemTrash. Tests never clean real personal folders. Temporary fixture cleanup uses FileManager removal only for its own generated tree.

## Measurements and limits

- Final synthetic scan: 3,000 ten-byte files, approximately **1.54 seconds** (fixture creation excluded). Measurements during development ranged roughly 0.45–1.72 seconds as metadata validation evolved and concurrent builds competed for resources. This is not a whole-disk throughput claim.
- A separate measured test-binary run (25-test checkpoint, before the final policy/input-only changes) used **91,881,472 bytes maximum resident memory**. It included the 3,000-file scan and presentation tests, without compiler memory. This does not establish the <250 MB target on millions of files.
- Startup smoke on a near-final Release build: visible window and initialized fresh test database at **1.37 seconds** after App initialization, including an intentional 250 ms wait for visibility. Whole process ran for about **1.55 seconds**; maximum resident memory was **100,237,312 bytes**. The smoke mode exits immediately after checking readiness. Later changes only tightened Library risk and numeric input handling.
- Reference hardware CPU model/RAM were not captured. These single-host samples are preliminary, not representative hardware benchmarks.

App startup initializes SQLite off the main actor. Scanner I/O is serial and batched; catalog pages are bounded at 300 visible records, folder columns at 150 directories each, duplicate candidates at 20,000 and read buffers at 1 MiB. Metadata rescans still enumerate the tree to detect removals but reuse unchanged identities. No filesystem-event daemon runs.

## Reproduce

```sh
SPACEMITHRA_TEST_MODE=1 swift test
python3 scripts/check_localization.py
scripts/release.sh
/usr/bin/time -l build/Build/Products/Release/SpaceMithra.app/Contents/MacOS/SpaceMithra \
  --ui-testing --smoke-test -onboarded YES -language en
```

The explicit UI test flag creates a fresh temporary support database instead of opening normal app history. The additional smoke flag waits for a visible window, reports readiness, and exits. It does not inject fake scan results.

The UI test initially failed because an unsigned runner was killed before connecting. Retrying with local ad hoc signing started XCTest but failed after a timeout enabling automation mode. The host’s simulator service also reports a version mismatch; these are macOS tests and no iOS simulator is required. Run UI tests in a properly configured logged-in macOS desktop session:

```sh
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -destination 'platform=macOS' -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
```

## Outstanding acceptance work

- Actual SystemTrash behavior and recovery on isolated test volumes, including external/unmounted/unsupported volumes; never use real personal files.
- Interrupted journal and restoration crash tests, disk-full/injected database-write faults, hostile concurrent path replacement review.
- Real-volume and million-file performance, peak memory and responsiveness under contention; cold-start measurements on specified reference hardware.
- macOS 13 runtime and actual Intel hardware. Cross-compilation alone is insufficient.
- Keyboard/VoiceOver traversal, Quick Look, confirmation cancellation through the UI, RTL, long translations, text size, Increase Contrast and Reduce Motion.
- Fluent-speaker review of draft translations.
- Independent safety/security review and signed/notarized distribution.

## Repository hygiene

The parent Macos repository remains the source-control root. An empty nested Git directory (no commits, tracked files or remotes) was discovered inside SpaceMithra and preserved at `/tmp/SpaceMithra-empty-nested-git-20261114-1515` so the project can be added normally to the parent repository. No source history was discarded. Generated build directories, packages and test fixtures are ignored. Nothing was committed, pushed or published.
