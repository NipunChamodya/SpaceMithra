# Architecture

SpaceMithra targets macOS 13+, Swift 6, SwiftUI, Foundation, CryptoKit and SQLite. No network service or external dependency is used.

The app model coordinates a read-only scanner actor, a SQLite catalog actor, deterministic risk rules, explicit protection rules, duplicate hashing, and an isolated cleanup service. SwiftUI renders paged catalog queries. File content is read only during user-initiated duplicate detection and Quick Look.

## Implementation checklist
- [x] Foundation: Xcode app, SQLite, navigation, settings
- [x] Explorer: streaming scan, directory totals, metadata, progress, cancellation
- [x] Cache intelligence: positive recognition, risk, persistent protection
- [x] Cleanup: explicit queue, revalidation, journal, Trash, recovery
- [x] Analysis: duplicates, developer records, interactive chart
- [ ] Localization and accessibility: seven locales, RTL, keyboard controls
- [ ] Release: tests, measurements, documentation, release build

## Modules
`Core`: immutable records, identities, rules and errors.
`Services`: catalog, scanner, protection, cleanup, duplicates.
`Features`: main-actor presentation model and SwiftUI views.
`App`: composition root. Tests use isolated temporary fixtures.

## Filesystem safety model
Scanning never mutates scanned files. Symlinks are cataloged but never traversed. Packages are traversed for size but descendants are ineligible for cleanup. Hard-linked content is counted once in aggregate estimates using a disk-backed inode index. Rescans reuse unchanged identity metadata from one prior catalog generation. Allocated size is an estimate and APFS shared extents cannot be resolved through these APIs.

Cleanup accepts only explicit file selections from a completed scan. It refuses symlinks, directories, packages, system paths, cloud-managed files, protected paths, hard links, and unavailable metadata. Parent path resolution and device/inode/size/mtime/ctime are checked again immediately before Trash. The app does not invoke shell cleanup commands or permanent deletion. Foundation Trash has no atomic identity-bound operation: external path replacement during the final syscall remains a limitation. Conservative refusal and immediate validation reduce but cannot eliminate this race.

A durable pending journal entry must precede every Trash move. The returned Trash URL and result are persisted. A process crash between Trash and journal update leaves an uncertain operation; it must never be retried automatically. Restore checks the recorded destination and refuses conflicts. Moving to Trash does not reclaim disk space.

## Release gates still open
- [ ] Independent deletion-safety review, especially the Foundation path race
- [ ] Actual system Trash / external-volume recovery manual acceptance
- [ ] macOS 13 and Intel runtime testing
- [ ] Native UI automation (runner cannot enable automation in this session)
- [ ] VoiceOver, contrast, long text and RTL manual acceptance
- [ ] Fluent-speaker review for six draft translations
- [ ] Reference-hardware startup and large-volume memory benchmarks
- [ ] Developer ID signing/notarization for trusted public binary distribution

No live-use detector, shell cleanup commands, permanent deletion, or folder Trash operations are implemented. The app explains these limits and leaves affected items protected or requiring review.
