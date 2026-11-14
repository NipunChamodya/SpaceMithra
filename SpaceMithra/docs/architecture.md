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
- [x] Three native UI smoke scenarios, including seven resource locales (manual acceptance remains open)
- [ ] VoiceOver, contrast, long text and RTL manual acceptance
- [ ] Fluent-speaker review for six draft translations
- [x] Identified M2/8 GB startup and synthetic 50,000-file CPU/memory measurements
- [ ] Full-volume realistic workload and rendering/idle profiling
- [ ] Developer ID signing/notarization for trusted public binary distribution

No live-use detector, shell cleanup commands, permanent deletion, or folder Trash operations are implemented. The app explains these limits and leaves affected items protected or requiring review.

## 0.2.0 beginner-first overhaul (current)

Current work supersedes the historical checkpoint counts and bounded-candidate implementation above. See [the bug-fix report](overhaul-report.md) and [production-readiness checklist](production-readiness.md).

`FileLocation` validates local absolute URLs, rebuilds mounted-root representations, and centralizes containment/parent/breadcrumb boundaries. Dot normalization is lexical so Foundation cannot turn real `/private/var` directories into `/var` symlinks; both real system paths and their aliases remain protected. `VolumeService` reads authoritative capacity independently of the catalog; `DiskScanAccounting` explicitly separates estimated known allocation from capacity, with no fabricated snapshot/purgeable attribution.

`CatalogMigration` adds indexed logical sizes, dates and Unicode-folded names to legacy records in bounded batches. Scan generations and `ScanCatalogContext` preserve coverage and interruption state. SQL filters run before paging; `CatalogOverview` computes exclusive dashboard buckets from the complete current catalog, rather than current explorer rows.

`CatalogDuplicates` owns persistent candidate/work/result tables, resumable checkpoints, group/copy paging and keeper proofs. `Duplicates` performs sequential descriptor-validated staged reads in batches of 128. Cancellation can interrupt the SQL seed; changing scan generations prevent stale publication. Old verified proofs remain available to cleanup even when their preview pages are invalidated. `CleanupJournal` now also supplies keeper validation before review/cleanup.

`ApplicationInventory` and `DeveloperAnalyzer` are separate metadata-only actors; neither executes tools or deletes. Application association requires exact bundle identifiers. Developer storage kinds distinguish cache, dependency store, environment, installation, artifact and user data. Classification by source extension alone no longer implies disposable developer storage.

`WelcomeView`, `ScanningView`, `DashboardView`, `ApplicationsView`, `DeveloperStorageView`, `DesignSystem` and `ErrorMessageView` provide progressive disclosure around the retained explorer/review/recovery screens. AppModel remains the main-actor coordinator; hashing, catalog and enumeration stay in service actors. Native UI test mode always injects rejecting Trash operations and uses an isolated database. Optional auto-scan fixtures must reside within the dedicated temporary UI-fixture boundary.

The 0.2.0 universal release is staged in `build-overhaul`, preserving previous build directories and release ZIPs. Ad hoc signing and synthetic tests are development verification, not public-distribution approval.
