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
