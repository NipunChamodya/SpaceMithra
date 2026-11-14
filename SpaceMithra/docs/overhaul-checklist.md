# Beginner-first overhaul — requirements and execution

Existing app, cleanup/recovery guarantees and release artifacts are retained. Branch: overhaul/beginner-storage-correctness. No private files are used for cleanup testing.

## P0 — correctness
- [ ] Canonical validated file URL navigation, root-bounded parents and breadcrumbs
- [ ] Reproduce mounted-root `..` failure; metadata/root regression tests
- [ ] Authoritative startup capacity at launch, separate from incomplete scan coverage
- [ ] Avoid System/Data capacity summation and repeated-volume traversal
- [ ] Existing cleanup, protection, cancellation, journaling and recovery tests remain passing

## P1 — scalable analysis
- [ ] SQLite-backed duplicate work queue: bounded batches, staged hashes, resumable safe checkpoints, no 20,000-file hard stop
- [ ] Synthetic 25,000- and 50,000-candidate stress tests and measurements
- [ ] Recognized developer installations, caches, stores, environments and artifacts; no source-as-junk classification
- [ ] Application inventory cards before package contents, explicit attribution limits
- [ ] Stale results, hidden filters and interrupted scan handling

## P2/P3 — beginner UX
- [ ] Welcome / Scan My Mac, language choice and privacy-first permission guidance
- [ ] Actual progress / indeterminate animation with Reduce Motion
- [ ] Capacity / coverage dashboard, category cards and review-only recommendations
- [ ] Progressive technical details and advanced exploration retained
- [ ] Seven-language coverage with honest draft/untranslated flags
- [ ] Keyboard, accessible chart descriptions, clear non-color risk and focus controls

## P4 — validation
- [ ] Full automated suite, native UI acceptance where host permits
- [ ] CPU / memory / timing benchmarks on identified host, no hardware assumptions
- [ ] Release and Debug build, universal package and checksum under new version
- [ ] Bug report, architecture and explicit production blockers updated

## Reproduced evidence before editing
The mounted root from FileManager.mountedVolumeURLs has path `/`, but deleting its last path component returns `/..` on this host. FileMetadata.read starts its package-ancestor walk from that parent. Newly constructed directory URLs for `/` instead return `/` as parent. This is a Foundation URL representation behavior, not a UI-only filename issue.

Capacity UI is gated by model.root and does not initialize startup volume capacity. It is therefore absent before scanning. The dashboard treemap uses whichever paged explorer rows were last queried, not a full-scan aggregate. The root and APFS Data volume both report 245107195904 bytes on this machine at the read-only probe; those totals must never be summed. Disk usage is not the sum of logical file lengths.

Known open gates: no guarantee of atomic Foundation Trash paths; actual system Trash/external volumes, macOS 13/Intel hardware, VoiceOver/manual layouts, translation review and signed/notarized public distribution need separate acceptance. Unit tests alone cannot close these gates.
