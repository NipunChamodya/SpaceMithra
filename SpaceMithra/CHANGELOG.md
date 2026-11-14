# Changelog

## 0.1.0 — development preview

Initial native app: SQLite-backed scans, folder exploration, risk/protection rules, cache/developer inspection, explicit cleanup review, Trash/recovery journal, duplicate hashing, charts, draft seven-language catalog and synthetic-fixture tests. Not yet a production release; see README release gates.

### Safety follow-up

- Revalidate restore paths, Trash identity and destination conflicts after the journal suspension.
- Verify restored modification time and link count in addition to inode/device/size.
- Inject journal failures in isolated tests; stop batches when result persistence fails.
- Expand the suite from 28 to 33 passing tests.
- Allow a separate release build directory to preserve an already running app.
