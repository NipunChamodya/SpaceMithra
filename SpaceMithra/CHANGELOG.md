# Changelog

## 0.1.0 — development preview

Initial native app: SQLite-backed scans, folder exploration, risk/protection rules, cache/developer inspection, explicit cleanup review, Trash/recovery journal, duplicate hashing, charts, draft seven-language catalog and synthetic-fixture tests. Not yet a production release; see README release gates.

### Safety follow-up

- Revalidate restore paths, Trash identity and destination conflicts after the journal suspension.
- Verify restored modification time and link count in addition to inode/device/size.
- Inject journal failures in isolated tests; stop batches when result persistence fails.
- Expand the suite from 28 to 33 passing tests.
- Allow a separate release build directory to preserve an already running app.

### Cleanup review and recovery follow-up

- Add read-only preflight of exact selected records, with identity/protection/path/permission blockers.
- Bind confirmation to an immutable review snapshot; changing the queue or cancelling invalidates consent.
- Group recovery history by cleanup session, with separate outcome counts and estimated selected bytes.
- Expand regression coverage to 38 passing tests and localization to 164 keys in seven languages.

### Recovery availability and cancellation follow-up

- Add timestamped read-only availability checks for Trash entries and original-path conflicts; unavailable entries cannot be restored from the UI.
- Allow cancelling preflight while it is waiting or checking files, without a late approval appearing.
- Exclude cloud-classified and unestablished file types from duplicate hashing; recheck metadata before opening content.
- Expand to 42 passing tests and 173 localization keys across seven languages.

### Duplicate-analysis safety follow-up

- Read through validated descriptors with no-follow traversal of every path component and nonblocking rejection of special-file replacements.
- Bound content reads to the scanned length and validate descriptor/path identity after hashing.
- Continue past per-file failures with bounded issue details and explicit partial-result warnings.
- Remove stale earlier hashes during final result validation.
- Preserve known duplicate-copy safeguards across cancelled refreshes and reject approval of every known copy, including previously queued items.
- Route the global Cancel command to active preflight or duplicate analysis before scan cancellation.
- Expand to 52 passing tests and 177 localization keys in seven languages.

### Cleanup cancellation and progress follow-up

- Show cleanup progress and route Cancel / Cmd-. to the active cleanup batch.
- Observe cancellation at safe checkpoints; finish and journal any move already underway.
- Record unstarted items as cancelled without attempting a move, and retain them in the queue for fresh review.
- Use a lock-protected cancellation token so an immediate request cannot be lost before the worker starts.
- Cover journal failures and cancellation during a move; expand to 59 passing tests and 181 keys across seven languages.

## 0.2.0 — beginner-first storage overhaul (development preview)

- Fix mounted Macintosh HD `..` ancestry, root boundaries, self-child aggregation and root protection inheritance.
- Read authoritative startup capacity independently of partial scans; avoid System/Data double counting.
- Replace the 20,000-candidate duplicate cutoff with bounded, resumable SQLite work, staged SHA-256 and paged keeper-aware results.
- Add application overview cards, expanded recognized Node/Python/tool inventory, welcome/Scan My Mac, read-only progress and category dashboard.
- Correct indexed paging filters, Unicode search, legacy migration, stale classifications/results and interrupted scan reporting.
- Preserve real private-directory identity during lexical path normalization; protect system aliases and format bytes/dates in the selected language.
- Preserve explicit cleanup review, safe in-flight cancellation, durable history and conflict-aware recovery.
- Expand seven-language draft resources and accessible, motion-aware native components.
- Preserve 0.1.0 artifacts; stage universal 0.2.0 separately. Public release acceptance remains open.
