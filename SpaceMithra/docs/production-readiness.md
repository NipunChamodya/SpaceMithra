# 0.2.0 production-readiness checklist

This is a development preview. Passing synthetic tests alone does not establish public-release safety.

## Implemented and covered by regression tests
- [x] Canonical Macintosh HD metadata, bounded parents/breadcrumbs, invalid URL rejection
- [x] Authoritative startup capacity independent of scan coverage, no System/Data summation
- [x] Read-only streaming scans, cancellation, links, permissions and bounded query pages
- [x] Disk-backed duplicate batching, resume, exact full hashes, change handling and paged keepers
- [x] Real-file 25,000/50,000 stress scenarios (opt-in)
- [x] Node/Python/tool inventories and application attribution fixtures
- [x] Protection, explicit review, identity validation, journal failures, recovery conflicts
- [x] In-flight cleanup cancellation finishes/journals its move and keeps remaining queue items
- [x] Legacy catalog migration, Unicode search, SQL filters and persisted scan coverage
- [x] Seven-language resource presence, visible untranslated/review states

## Implemented, requiring interactive acceptance
- [x] Native test-mode welcome, read-only fixture overview/application cards and keyboard navigation smoke
- [x] All seven compiled welcome resource bundles load their own expected button text
- [ ] Manual full Scan My Mac/review workflows on representative user setups
- [ ] VoiceOver reading/focus order, real screen-reader chart alternative and progress usability
- [ ] Sinhala/Tamil glyph rendering and long text at supported window sizes
- [ ] Arabic RTL and mirrored navigation, all seven languages reviewed by fluent speakers
- [ ] Reduced Motion, increased contrast, light/dark appearance and external displays
- [ ] Quick Look and Finder integration on supported OS versions

## Public release blockers
- [ ] Independent filesystem safety review, including final Foundation path race
- [ ] Actual system Trash and restore on isolated test volumes; unavailable Trash and disconnection
- [ ] macOS 13 and Intel runtime acceptance (universal compilation is insufficient)
- [ ] Full-volume realistic workload performance, idle CPU and rendering profiling
- [ ] Crash/termination and permissions-change acceptance on real supported filesystems
- [ ] Developer ID identity, hardened-runtime distribution audit, notarization and Gatekeeper acceptance

## Intentional limits

No exact physical attribution of snapshots, purgeable/protected data or shared APFS extents; no active-use certainty, filesystem-event monitoring, permanent deletion, folder cleanup, automatic tool cleanup execution or guessed application leftovers. Developer inventory cards cap at 1,000 locations and app inventory at 2,000 bundles; file scans/duplicate work are disk-backed rather than constrained to those UI inventories. A new scan replaces the browsable catalog but preserves queue records, recovery journal and conservative duplicate keeper proofs.
