#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/check_localization.py
SPACEMITHRA_TEST_MODE=1 swift test
