# Filesystem safety

## Boundaries

The app runs as the current user without a privileged helper. It respects TCC and ordinary filesystem access checks. The app is deliberately not App Sandbox-enabled because this preview supports direct user-selected local exploration; it does not bypass macOS privacy restrictions. It never requests Full Disk Access at startup.

Metadata reads use lstat and Foundation resource values. Directory enumeration does not follow symbolic links. Symbolic-link roots or ancestors are refused. Package descendants are cataloged for totals but blocked from cleanup. SQL inserts are batched at 128 entries. One scanner performs metadata I/O; it does not launch an unbounded task per file.

Hard-linked regular files retain logical size in details; device+inode deduplication counts their content once in totals. Cleanup refuses all multiply linked files. Allocated bytes are reported only when available. APFS clones, compression, sparse extents, snapshots and Trash retention make logical/allocated bytes unsuitable as guaranteed reclaimable space.

## Cleanup transaction

1. UI captures exact records in an explicit queue and shows all selected paths and consequences in a confirmation sheet.
2. Cleanup persists a pending operation before any filesystem mutation. Journal errors abort the batch.
3. It reloads protection rules for each file and applies system restrictions independently.
4. It rejects changed identity (device, inode, length, modification time, change time, link count), symbolic-link paths and unsupported metadata, and checks parent writability.
5. Immediately before Trash, it repeats identity validation without an intervening suspension.
6. Foundation `trashItem` is the only cleanup operation. No permanent-delete fallback exists.
7. The returned destination and its new identity are saved. An attempted operation that cannot confirm success is uncertain and is never automatically retried.

A crash after Trash but before journal completion leaves pending history requiring manual Trash inspection. `pending`, `uncertain` and `restoring` are deliberately not automatically recoverable. The app cannot guarantee an uninterrupted atomic transaction between SQLite and the filesystem.

## Restore

Only a stored successful Trash entry with a matching Trash identity can be restored. The original parent must not resolve through symbolic links. lstat rejects any destination conflict, including dangling symlinks. FileManager move does not overwrite existing paths. Restores are journaled before moving. Because journal persistence suspends execution, Trash identity, resolved paths and destination conflicts are checked again after the journal write, without suspension before the move. After moving, inode, device, size, modification time and link count are verified; ctime may change during rename. Partial or interrupted restores remain uncertain. Cross-volume identity changes are conservatively reported as unverified rather than falsely successful.

## Remaining races

Foundation Trash and move operations accept paths, not open inode descriptors. Another process can replace a path between validation and operation. This is a documented release risk, not a claim of race-free deletion. Stop affected applications and avoid concurrently changing directories. The app does not execute file contents or shell strings from filenames.

Protection rules bind exact normalized paths and explicit descendant boundaries; `/a/b` cannot match `/a/brother`. File identities must still match the reviewed record. Rules for future items apply only beneath that explicit path and can expire after 24 hours. System restrictions cannot be overridden through user rules.
