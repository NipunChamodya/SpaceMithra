#!/usr/bin/env python3
"""Prepare a read-only native UI fixture outside the UI runner's App Management scope."""
from pathlib import Path
import plistlib
import uuid
base = Path('/private/tmp/SpaceMithra-UITest-Fixtures')
base.mkdir(mode=0o700, parents=True, exist_ok=True)
if base.is_symlink() or base.resolve() != base:
    raise SystemExit('UI fixture base must be a real directory')
root = base / str(uuid.uuid4())
contents = root / 'Applications' / 'Example.app' / 'Contents'
contents.mkdir(parents=True)
(contents/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.spacemithra.fixture','CFBundleName':'Example','CFBundleDisplayName':'Example'}))
(root/'fixture-owner.txt').write_text('SpaceMithra synthetic UI fixture\n')
(base/'current-fixture.txt').write_text(str(root))
print(root)
