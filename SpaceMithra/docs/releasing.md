# Release

1. Complete all unchecked gates in architecture.md and testing.md; do not label the preview production-ready.
2. Run scripts/test.sh and build both architectures. Test actual macOS 13 and Intel hardware; cross-compiling is insufficient.
3. Run scripts/release.sh to produce a locally ad hoc signed universal app, ZIP and checksum. No upload occurs.
4. For a publicly trusted binary, configure your own Developer ID Application certificate, sign with hardened runtime and timestamp, then notarize with `xcrun notarytool` using your credentials, staple and verify with `spctl`. Never commit signing keys or credentials. The project has no signing team configured.
5. Publish the source, license, changelog, actual test results, binary, SHA-256 and known limits manually to GitHub Releases after review. No GitHub remote, publishing, or Homebrew cask is set up by this repository.

All functionality and source remain free. Optional signing infrastructure must not introduce a subscription requirement in the app. Local source builds do not require a paid API or external service.
