# Filesystem safety

## Boundaries

The app runs as the current user without a privileged helper. It respects TCC and ordinary filesystem access checks. The app is deliberately not App Sandbox-enabled because this preview supports direct user-selected local exploration; it does not bypass macOS privacy restrictions. It never requests Full Disk Access at startup.

Metadata reads use lstat and Foundation resource values. Directory enumeration does not follow symbolic links. Symbolic-link roots or ancestors are refused. Package descendants are cataloged for totals but blocked from cleanup. SQL inserts are batched at 128 entries. One scanner performs metadata I/O; it does not launch an unbounded task per file.

Hard-linked regular files retain logical size in details; device+inode deduplication counts their content once in totals. Cleanup refuses all multiply linked files. Allocated bytes are reported only when available. APFS clones, compression, sparse extents, snapshots and Trash retention make logical/allocated bytes unsuitable as guaranteed reclaimable space.

## Cleanup transaction

1. A read-only preflight checks exact queued records, their identity, protection, resolved paths and parent writability. It never replaces stale approved identities with fresh ones. UI captures an immutable review snapshot and shows all paths, consequences and blockers. Confirmation requires no blockers and an unchanged selection; cancellation invalidates the snapshot. Preflight does not guarantee that Trash will be available when the operation runs.
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

## Recovery availability

The recovery screen performs read-only, timestamped inspections of recorded Trash identities and original destinations. Missing Trash paths, changed identities or symbolic-link paths, occupied original locations and unverified permissions disable Restore. Inspection does not change historical operation outcomes: a file that was successfully moved remains historically moved even if Trash was later emptied. Availability is only a snapshot and does not authorize a filesystem operation; the restore engine independently revalidates after confirmation.

Preflight can be cancelled while awaiting journal protection rules or between metadata checks. Cancellation cannot persist a cleanup entry, create an approval, or move a file. An in-progress filesystem metadata syscall itself is not interruptible.

## Duplicate content reads

Duplicate hashing uses validated read-only file descriptors, with no-follow openat traversal of all parent components and the leaf. A FIFO replacement cannot block waiting for a writer because the leaf is opened nonblocking and fstat must establish the exact recorded regular-file identity before any content is read. Reads stop at the scanned length even if a file grows. Changed or unreadable candidates are skipped and reported; cancellation is propagated rather than converted into a skipped-file result. Files whose earlier hashes become stale are removed before results are displayed.

These descriptor checks protect duplicate reads. They do not remove the separately documented Foundation path race in Trash/restore operations. Both duplicate results and recovery availability remain time-limited snapshots. No copy is selected automatically, and known groups must retain an unselected copy at review and confirmation.

## Cleanup cancellation

Cancellation is a request to stop at a safe boundary, not an interruption of Foundation Trash. A lock-protected token accepts requests before the worker starts and while validation is running. The engine checks before starting an item, after journal/permission-rule suspensions, and immediately before its final validation-and-move sequence. Once a move begins, it completes and its actual result is journaled before the next item is considered. Requests arriving after the last checkpoint can therefore still allow the current item to finish.

Every remaining approved record is journaled as cancelled without a Trash attempt. These records stay in the queue, but their old review approval is discarded. Retrying requires a new preflight and explicit confirmation. Recording cancellations can take time for a large batch; the stopping indicator remains visible until journaling finishes. A failed journal write still aborts the batch and surfaces an error rather than falsely reporting a fully recorded cancellation.

Caller-task cancellation is also observed at checkpoints, but the normal UI uses the explicit token rather than cancelling the task that must finish journaling. Neither cleanup nor cancellation permanently deletes data or empties Trash.
