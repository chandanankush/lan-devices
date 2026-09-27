# Development

Commands on this page run from the repository root unless stated otherwise.

## Requirements

- Xcode and its macOS command-line tools, selected for `xcodebuild`.
- The shared project targets macOS 14 or later, pinned explicitly as `MACOSX_DEPLOYMENT_TARGET = 14.0`. If a local Xcode upgrade changes it (for example, to `$(RECOMMENDED_MACOSX_DEPLOYMENT_TARGET)`), restore the explicit value before committing.
- `/usr/bin/ssh` and `/usr/bin/ssh-keyscan` for the system SSH implementation.
- `/usr/bin/expect` for password-based remote commands in the default build. Verify that it exists on the target Mac.

SwiftUI, AppKit, Foundation, Combine, Network, CryptoKit, and SQLite3 come from the macOS SDK. NMSSH is optional and is not required by this repository.

`xcpretty` is optional for formatted build output. `fswatch` is needed only for the source watcher.

## Build and run

```sh
make build
make run
```

`make run` builds and opens the app. Build output goes into `.derived/` in the directory where the Makefile runs. `make clean` removes that directory.

For Xcode, open `LanDeviceConnect/LanDeviceConnect.xcodeproj`, select **LanDeviceConnect** and **My Mac**, and run. Choose a signing team if required. Personal signing settings should remain local.

For an explicit unsigned build:

```sh
xcodebuild -project LanDeviceConnect/LanDeviceConnect.xcodeproj \
  -scheme LanDeviceConnect \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath .derived \
  build MACOSX_DEPLOYMENT_TARGET=14.0 CODE_SIGNING_ALLOWED=NO
```

This override keeps verification on the documented minimum target even if local Xcode settings were upgraded. It does not establish runtime compatibility on every macOS version. For release validation, repeat the command with `-configuration Release` and test the resulting app on supported Macs.

An unsigned local build is not a notarized distribution. Signing, notarization, and release packaging require separate verification.

## Tests and warnings

```sh
make test
```

The standalone tests compile with warnings treated as errors. They cover TCP reachability, connection/timeout races, invalid ports, refreshes that overlap additions/removals, discovery merging, metadata updates, malformed records, and a locally published PTR record with lookup timeout/cancellation checks.

Repository tests substitute an in-memory store and do not read the real device database. Network fixtures use local listeners and local-only DNS-SD registration rather than remote power commands.

To enable Thread Sanitizer:

```sh
bash LanDeviceConnect/scripts/test.sh --sanitize-thread
```

For compiler warning checks, append `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES` to the explicit build command. Review the full build log and exit status. The project disables App Intents metadata extraction because it defines no App Intents.

## Manual UI checks

Use disposable example devices and a recording SSH client when verifying power commands. Never test shutdown/restart against an active device just to exercise the UI.

Check these flows before changing navigation or selection:

- Add Device stays in the existing window; Back, Cancel, and Escape return to Devices.
- Row text, empty row space, and keyboard selection populate Name, Host/IP, and Port together.
- Selection stays visible while editing; rapid switching leaves the final device selected; credentials remain intact.
- Save works both directly and after host-key review.
- Each power action opens the correct device/action confirmation. Cancellation sends no command; confirmation sends one command to the selected endpoint.
- The right-click power menu uses the same confirmation.

## Source watcher

From the application directory:

```sh
cd LanDeviceConnect
bash scripts/watch.sh
```

The watcher requires `fswatch` and rebuilds when source folders change. It does not automatically relaunch the app.

## App icon

```sh
make icons
```

The exporter uses AppKit to render `LDCIconGenerator.swift` into `LanDeviceConnect/App/Assets.xcassets/AppIcon.appiconset`. Small variants omit fine details.

| Points | 1× pixels | 2× pixels |
| --- | --- | --- |
| 16 × 16 | 16 × 16 | 32 × 32 |
| 32 × 32 | 32 × 32 | 64 × 64 |
| 128 × 128 | 128 × 128 | 256 × 256 |
| 256 × 256 | 256 × 256 | 512 × 512 |
| 512 × 512 | 512 × 512 | 1024 × 1024 |

These are the ten slots in [Apple's app icon asset format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html). Inspect the rendered sizes and the built app icon before publishing changes.

## Public repository hygiene

Use documentation-only examples such as `demo-device.local`, username `demo`, and `192.0.2.10`. The latter belongs to a range [reserved for documentation](https://www.rfc-editor.org/rfc/rfc5737).

Do not commit device databases, private keys, passwords, real-device screenshots, logs, signing material, or personal Xcode state. Ignore rules are preventative; they do not remove files already tracked by Git.

Review the diff and run a local secret scan before publishing. With [Gitleaks](https://github.com/gitleaks/gitleaks) available:

```sh
gitleaks git --redact --log-opts="--all" .
```

This scans local Git history, not unpublished working-tree edits. Also scan the files intended for the next commit using `gitleaks dir` on an isolated copy. Keep reports outside the repository and redact findings before sharing them. Scans do not replace visual review of screenshots or manual review of sensitive data.

See the [security review](security-review.md) for the scope and findings of the current documentation cleanup.
