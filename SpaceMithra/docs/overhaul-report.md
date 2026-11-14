# SpaceMithra 0.2.0 overhaul report

Status: development preview. This report separates implemented behavior from public-release acceptance. Existing application code, queue/history behavior, old release ZIP and running app are retained. Development branch: `overhaul/beginner-storage-correctness`.

## Reproduced critical defects

1. **Invalid `..` on Macintosh HD.** On this host the mounted startup URL has path `/`, but Foundation's parent operation on that URL returns `/..`. The metadata package-ancestor loop repeatedly appended parents, reproducing the exact invalid-filename exception after 342 iterations. Canonical file URLs are now rebuilt from validated absolute paths. Parent traversal and breadcrumbs stop at the scan boundary. Metadata, scanner and navigation share this policy; this is not a UI-only workaround.
2. **Incomplete capacity presentation.** Startup capacity was gated by an existing scan, and a paged explorer treemap stood in for the disk overview. Startup capacity is now read independently using macOS volume resource values. Both startup root and APFS Data reported **245,107,195,904 bytes** here; they are never summed. Capacity uses decimal GB consistently. Logical scan categories, known allocated estimates, used/free capacity and unattributed estimates are distinct. Exact protected/system physical bytes, snapshots and purgeable bytes are explicitly unavailable through this implementation, rather than invented.

## Implemented

- Read-only Scan My Mac, first-run welcome, language picker, privacy/permission explanation and optional advanced navigation. Scan progress reports actual items/bytes, uses an indeterminate ring and respects Reduce Motion. No percentage or remaining-time estimate is fabricated.
- Capacity/coverage dashboard with eight exclusive logical categories and review-only suggestions. Downloads take precedence over file type so categories do not double-count. Partial/interrupted coverage and APFS allocation limitations remain visible.
- Application overview cards with actual icons and separate measured bundle/cache/associated-data sizes. Attribution requires an exact bundle-identifier path. Unmeasured/unknown data and unavailable leftovers are shown honestly. Technical files require disclosure. No arbitrary associated-data uninstaller.
- Developer inventory discovers existing readable Node/npm/Yarn/pnpm/version-manager, Python/pip/Poetry/uv/Conda, Xcode, Homebrew, Docker, Gradle/Maven/Cargo/Go/Dart/Flutter locations. Project markers distinguish dependencies/environments/build outputs from source. Sources and environments are not disposable cache. Trusted tool inspection commands can be previewed/copied; no commands are executed.
- SQLite-backed duplicate work queue: 128-record batches, size grouping, first/last-content sampling, bounded full SHA-256 reads, final identity validation, cancellation and generation-bound checkpoints. Results page 200 groups and 100 copies. Completed proofs protect an unselected keeper across pages and rescans. Empty files are supported; hard links, packages and cloud-managed content are excluded. APFS clone sharing cannot be established.
- Durable scan context, interrupted-scan reporting, root/Data traversal exclusions and disk-backed inode/directory deduplication. Scanner remains metadata-only, cancellable and read-only.
- Friendly error summaries with expandable technical details; simple file details first. Advanced explorer, cache groups, Keep/Clean/Protect, review, history and recovery remain available.
- Byte/date formatting follows the selected language, including numeric zero sizes. 298 keys in all seven string-catalog locales. All six non-English resources remain explicitly `needs_review`, including Sinhala/Tamil. English fallback is not counted as translation approval. Arabic uses RTL; OS filenames/descriptions remain system-provided.

## Additional defects supported by code and tests

- Root records could appear as their own children; root depth ordering and parent representation are corrected.
- Root protection used a `//` descendant prefix; normalized containment now correctly protects descendants.
- Foundation path standardization could replace real `/private/var` directories with `/var` symlink paths. Dot-component normalization is now lexical, preserving the original filesystem identity. `/var`, `/etc` and `/tmp` aliases remain system-protected. A read-only metadata regression verifies the real directory is not turned into a symlink.
- Biggest-file/date/extension/hidden filtering happened after paging; filters now run in indexed catalog queries before LIMIT/OFFSET.
- SQLite ASCII-only name matching missed localized names; normalized Unicode search keys and legacy migration preserve Sinhala combining marks and case-fold other scripts.
- Old cached classifications survived changed rules; rescans now reclassify unchanged metadata.
- Navigating from a dashboard category could retain the old category/path scope; folder navigation clears it.
- Scan elapsed time kept growing after completion; it now uses a fixed finish time. Interrupted persisted scans require a fresh completed scan before cleaning.
- Rescanned catalogs could expose old duplicate pages; publication is generation-bound while keeper proofs are retained conservatively.
- Legacy eight-column catalogs migrate bounded batches without discarding recovery history.
- The proposed npm inspection command uses `npm config get cache`; `npm cache verify` can modify the cache and is not presented as a read-only inspection. No tool command is executed by the app.

## Safety preserved

Every cleanup still requires an immutable explicit review. Identity, permissions, protections and known duplicate keepers are revalidated. No permanent deletion, Trash emptying, privileged helper or shell cleanup exists. Moving to Trash is never reported as reclaimed space. Cancellation finishes and journals an already-started move, retains unstarted items in the queue and requires a new review. Tests use injected fixture-only operations; native UI test mode rejects every Trash/restore operation.

Foundation's final path-based Trash/restore syscall is not an atomic inode-bound transaction. Independent review and actual system-Trash/test-volume acceptance remain necessary. No test result proves the absence of data-loss risks.

## Validation and artifacts

Final validation: 85 non-stress regression tests and three native UI tests pass, with separate 25,000/50,000 real-file runs passing. Final-source 50,000-file analysis: 244.45 s; peak process RSS 158.20 MiB. See [testing](testing.md) for scope, current runs and measurements, [readiness checklist](production-readiness.md) for outstanding acceptance, and [architecture](architecture.md) for module boundaries.

The new app is built under `build-overhaul/Build/Products/Release/SpaceMithra.app`. The universal ZIP and version-specific checksum are `dist/SpaceMithra-0.2.0-macos-universal.zip` and `dist/SHA256SUMS-0.2.0.txt`. The previous ZIP is also preserved at `dist/archive/SpaceMithra-0.1.0-before-overhaul.zip`. Ad hoc signing supports local testing; this is not Developer ID signing or notarization.
