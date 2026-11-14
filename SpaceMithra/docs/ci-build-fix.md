# Universal CI build: SwiftUI type-checking failure

The first actual error in [run 43615374887](https://github.com/NipunChamodya/SpaceMithra/actions/runs/43615374887) is:

```text
StorageMap.swift:14:25: error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions
```

The diagnostic points at the treemap tile's nested `Button`/shape/conditional overlay/modifier expression. The failed command list includes `SwiftCompile normal arm64 ... StorageMap.swift`; x86_64 compilation was also running. Exit 65 is the build's result, not its cause, and the log does not establish an Intel-only defect.

## Environment comparison

| Setting | Failed GitHub runner | Local validation host |
|---|---|---|
| Xcode | 26.6, build 17F113 (runner inventory) | 27.2, build 27B52 |
| Swift compiler | Original log did not print its version; fixed workflow records it explicitly | Apple Swift 6.4.2 |
| macOS SDK | 26.5 | 27.2 |
| Host architecture | arm64 (`macos-26-arm64` image) | arm64 |
| Output architectures | arm64 + x86_64 | arm64 + x86_64 |
| Deployment target / language | macOS 13.0 / Swift 6 | macOS 13.0 / Swift 6 |
| Configuration / optimization | Release / `-O` | Release / `-O` |
| Active arch / signing | `ONLY_ACTIVE_ARCH=NO`, signing disabled | Same |

Only Xcode 27.2 is installed locally. The original source successfully builds locally using the failed run's Release/architecture settings; the exact Xcode 26.6 compiler failure cannot be reproduced on this host. Validation on the pinned CI compiler is therefore required before declaring the fix resolved.

## Changes

- Split each treemap tile into small `StorageTileButton` and `StorageTileLabel` views. Formatting enters as a concrete String; layout, color, navigation, accessible label, tooltip and the text alternative are retained. There are no compiler-timeout overrides or ignored errors.
- Share `scripts/build-universal.sh` between CI and release packaging. It requires both architectures and verifies each required slice with an individual `lipo -verify_arch` invocation. A generic macOS destination removes host-destination ambiguity.
- Use `macos-26` and explicitly select Xcode 26.6, preserving the compiler that exposed the problem rather than hiding it by upgrading CI. Log Xcode, Swift, SDK, OS and host architecture on every run.
- Update the deprecated Node 20 checkout action from v4 to v7.0.1 (Node 24). The failed hosted runner was 2.338.2, newer than checkout's documented Node 24 minimum 2.327.1. This workflow uses ordinary push/pull_request events, so v7's fork protections for privileged triggers do not require opt-outs.

## Verification

```sh
SpaceMithra/scripts/build-universal.sh /tmp/SpaceMithra-ci-fixed
cd SpaceMithra
SPACEMITHRA_TEST_MODE=1 SPACEMITHRA_STRESS=1 swift test
python3 scripts/check_localization.py
python3 scripts/prepare_ui_fixture.py
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra -configuration Debug \
  -derivedDataPath /tmp/SpaceMithra-ci-ui -destination 'platform=macOS' \
  SPACEMITHRA_BUNDLE_ID=org.spacemithra.ci-ui CODE_SIGN_IDENTITY=- test
```

CI builds into RUNNER_TEMP and local validation uses separate temporary build directories. Neither validation nor the shared build helper packages over existing v0.2.0 release ZIPs/checksums or replaces the running app. The release script's packaging behavior is retained for explicit release invocations.

The GitHub Actions run for the pushed fix must finish successfully. Local success alone, particularly with a newer compiler, is insufficient to declare this CI issue resolved.
