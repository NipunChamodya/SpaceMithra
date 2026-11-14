# Release

1. Complete all unchecked gates in architecture.md and testing.md; do not label the preview production-ready.
2. Run scripts/test.sh and build both architectures. Test actual macOS 13 and Intel hardware; cross-compiling is insufficient.
3. Run scripts/release.sh (or `scripts/release.sh build-safety` to use a separate build folder while another copy is running) to produce a locally ad hoc signed universal app, ZIP and checksum. No upload occurs.
4. For a publicly trusted binary, configure your own Developer ID Application certificate, sign with hardened runtime and timestamp, then notarize with `xcrun notarytool` using your credentials, staple and verify with `spctl`. Never commit signing keys or credentials. The project has no signing team configured.
5. Publish the source, license, changelog, actual test results, binary, SHA-256 and known limits manually to GitHub Releases after review. No GitHub remote, publishing, or Homebrew cask is set up by this repository.

All functionality and source remain free. Optional signing infrastructure must not introduce a subscription requirement in the app. Local source builds do not require a paid API or external service.

## 0.2.0 staging

Use `scripts/release.sh build-overhaul`. The app is `build-overhaul/Build/Products/Release/SpaceMithra.app`, ZIP `dist/SpaceMithra-0.2.0-macos-universal.zip`, and checksum `dist/SHA256SUMS-0.2.0.txt`. Verify from the project root with `shasum -a 256 -c dist/SHA256SUMS-0.2.0.txt`. Previous 0.1.0 ZIP/checksum remain unchanged; a second pre-overhaul copy is under `dist/archive/`. Do not build into a directory containing a currently running app.

For native acceptance, first run `python3 scripts/prepare_ui_fixture.py`, then use the separate UI bundle identifier shown in testing.md. This avoids stopping a normal running copy and keeps every UI file-moving operation disabled.
