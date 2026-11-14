# Cleanup rules

Risk levels are `low`, `reviewRequired`, `protected`, and `unknown`. The current conservative rule set deliberately assigns no LOW result because it cannot establish the absence of active use. Size and age never establish safety.

Protected: unrecognized user-Library state (including unknown caches), system directories, app support state, credential paths, Docker state, simulators, Xcode archives, links, folders, packages and package contents, cloud-managed paths, multiply linked files, recognized database extensions, and user rules. Fresh metadata is checked again before moving.

Recognized caches: Safari, Chrome, Firefox, Adobe, Xcode DerivedData, npm, Yarn, pnpm, pip and Homebrew at explicit user-home paths. A name alone is insufficient evidence. The cache explorer shows only discovered rules and categories. Regeneration is a possibility, not a guarantee. Actual ownership and whether an app currently holds a file open are unavailable and labeled accordingly.

Adobe media cache may support editing projects. Xcode DerivedData may require rebuilds. Package-manager caches may require downloads, so offline workflows may be affected. Xcode archives and simulator/Docker data may contain unique state and are protected. Arbitrary build directories are not treated as junk.

KEEP removes the current queue entry. CLEAN adds an eligible exact record to review without mutation. PROTECT creates a persistent exact or descendant path rule and removes that record from the queue. Every selected file appears in a review sheet; unknown files explicitly warn about possible personal/project data loss.

Docker, Homebrew and simulator cleanup commands are not executed. Tool-managed cleanup requires separate future integration with validated tool versions, dependency checks, and explicit review. Folder-level cleanup is disabled to prevent approving a directory while newly created descendants go unreviewed.
