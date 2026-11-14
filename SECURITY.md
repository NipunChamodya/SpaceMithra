# Security

Report vulnerabilities privately through the repository’s GitHub private vulnerability reporting feature when enabled. Do not publish private paths, file contents, recovery database dumps, or exploit details in public issues. The repository owner must enable private reporting before public distribution.

Security-sensitive code is in Core/FileRules.swift, Services/Cleanup.swift, Services/Catalog.swift and Services/Scanner.swift. Every change to eligibility, path resolution, journaling, or restoration requires independent review and isolated-fixture tests.

No administrator permission, network entitlement, shell cleanup, symlink traversal, automatic Trash emptying, or permanent deletion is part of this app. Local data includes sensitive paths and is stored in an owner-only application-support directory. No file contents are persisted. The SQLite catalog fails closed on corruption; never automatically discard a damaged recovery database.

A local process with the user’s privileges can alter files or the catalog. Foundation Trash is path-based, and validation cannot eliminate the final path replacement race. This preview is not intended to clean directories being modified by untrusted processes. See docs/filesystem-safety.md.
