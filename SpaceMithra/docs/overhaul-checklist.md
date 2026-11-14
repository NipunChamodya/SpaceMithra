# Beginner-first overhaul — requirements and execution

Existing app, cleanup/recovery guarantees and release artifacts are retained. Branch: overhaul/beginner-storage-correctness. No private files are used for cleanup testing.

## P0 — correctness
- [x] Canonical validated file URL navigation, root-bounded parents and breadcrumbs
- [x] Reproduce mounted-root `..` failure; metadata/root regression tests
- [x] Authoritative startup capacity at launch, separate from incomplete scan coverage
- [x] Avoid System/Data capacity summation and repeated-volume traversal
- [x] Existing cleanup, protection, cancellation, journaling and recovery tests remain passing

## P1 — scalable analysis
- [x] SQLite-backed duplicate work queue: bounded batches, staged hashes, resumable safe checkpoints, no 20,000-file hard stop
- [x] Synthetic 25,000- and 50,000-candidate stress tests and measurements
- [x] Recognized developer installations, caches, stores, environments and artifacts; no source-as-junk classification
- [x] Application inventory cards before package contents, explicit attribution limits
- [x] Stale results, hidden filters and interrupted scan handling

## P2/P3 — beginner UX
- [x] Welcome / Scan My Mac, language choice and privacy-first permission guidance
- [x] Actual progress / indeterminate ring; Reduce Motion implementation (manual motion acceptance remains open)
- [x] Capacity / coverage dashboard, category cards and review-only recommendations
- [x] Progressive technical details and advanced exploration retained
- [x] Seven-language coverage with honest draft/untranslated flags
- [x] Native keyboard-navigation smoke, text/symbol risk indicators and chart alternatives
- [ ] Manual VoiceOver, focus order, increased contrast and long-text/RTL acceptance

## P4 — validation
- [x] Full regression suite and three native UI acceptance scenarios (including seven actual language resources)
- [x] CPU / memory / timing benchmarks on identified host, no hardware assumptions
- [x] Release and Debug build, universal package and checksum under new version
- [x] Bug report, architecture and explicit production blockers updated

## Reproduced evidence before editing
The mounted root from FileManager.mountedVolumeURLs has path `/`, but deleting its last path component returns `/..` on this host. FileMetadata.read starts its package-ancestor walk from that parent. Newly constructed directory URLs for `/` instead return `/` as parent. This is a Foundation URL representation behavior, not a UI-only filename issue.

Capacity UI is gated by model.root and does not initialize startup volume capacity. It is therefore absent before scanning. The dashboard treemap uses whichever paged explorer rows were last queried, not a full-scan aggregate. The root and APFS Data volume both report 245107195904 bytes on this machine at the read-only probe; those totals must never be summed. Disk usage is not the sum of logical file lengths.

Known open gates: no guarantee of atomic Foundation Trash paths; actual system Trash/external volumes, macOS 13/Intel hardware, VoiceOver/manual layouts, translation review and signed/notarized public distribution need separate acceptance. Unit tests alone cannot close these gates.

P0 validated: 67 tests pass; universal 0.2.0 build succeeds. Bounded reproduction reaches the precise invalid `..` exception after 342 ancestor steps. File URLs are rebuilt before metadata reads; root-bounded navigation terminates. Root records use an empty parent and SQL root depth is zero, fixing self-child listings and root aggregate ordering. Capacity is loaded at startup independently of scan state. Exact snapshot/purgeable/protected byte attribution remains explicitly unavailable rather than inferred.

Current 0.2.0 checkpoint: 85 non-stress regression tests pass (87 total, 2 opt-in stress cases skipped). Separate 25,000/50,000 real-file runs pass, with final-source 50,000 peak RSS 158.20 MiB. Three native UI tests pass, including all seven language welcome resources and read-only fixture/application cards. Debug and universal Release builds pass, ad hoc signature and new/preserved ZIP checksums verify. Final-artifact visible-window launch: 2.050 s under stress load (earlier checkpoint: 1.864 s). See overhaul-report.md, testing.md and production-readiness.md for scope and limits.
