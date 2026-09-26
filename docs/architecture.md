# Architecture

LanDeviceConnect is a SwiftUI macOS application. It uses macOS frameworks and system SSH tools; the default build has no third-party SSH library.

## Main components

| Component | Responsibility |
| --- | --- |
| `LDCLanDeviceConnectApp` | Creates the shared repository and Devices window. |
| `LDCDeviceListView` | Routes between Devices and Add Device inside the active window; owns power-action confirmations. |
| `LDCAddDeviceFlowView` | Owns form values, discovered-device selection, and discovery lifetime. |
| `LDCAddDeviceFormView` | Validates required values and presents host-key review before saving. |
| `LDCDeviceRepository` | Coordinates persistence, polling, remote commands, and sudo prompts on the main actor. |
| `LDCDeviceStore` | Reads and writes device records through SQLite3. |
| `LDCDiscoveryService` | Combines SSH endpoints with names and advertised metadata. |
| `LDCStatusChecker` | Checks TCP reachability of a host and port. |
| `LDCSSHClient` | Defines the asynchronous remote-command interface. |

All custom Swift types use the `LDC` prefix. Sources live in `App`, `Models`, `Services`, `ViewModels`, and `Views`. Standalone regression checks and database fixtures live in `Tests`; build utilities live in `scripts`.

## Navigation and selection

Each Devices window has its own Add Device navigation state. The + button and focused-scene Command-N binding route within that window. Save, Back, Cancel, and Escape return to Devices.

Discovered rows use stable UUID tags. One list-selection binding updates the highlight and Name, Host/IP, and Port in the same transaction. Selection feedback is brief, cancellable when switching devices, and disabled by Reduce Motion. Background enrichment changes row metadata without automatically replacing form edits.

Power icons and context-menu actions create a pending device/action request. The repository receives the remote command only after the user confirms that request. A later sudo prompt is an authentication step, separate from the action confirmation.

## Discovery

Bonjour browsing finds `_ssh._tcp.` endpoints. `_workstation._tcp.`, `_smb._tcp.`, and `_device-info._tcp.` advertisements supply identification only; they do not create non-SSH rows.

The subnet scanner chooses a local IPv4 interface and probes port 22 in its assumed `/24` range. This is a discovery heuristic, not a full enumeration of the network.

Matching hostname/IP endpoints and SSH ports merge into one row while preserving its UUID. Names and TXT-record manufacturer/model values enrich that row. Different SSH ports remain separate endpoints. TXT text is decoded and checked before display; manufacturer is not inferred from IP addresses or SSH software.

After subnet results arrive, asynchronous DNS-SD PTR queries try the configured resolver and multicast responders. Lookups time out after two seconds and are cancelled when discovery stops or rescans. A PTR name is used for display; a subnet result keeps its scanned IP as the connection target.

## Status and concurrency

Saved devices are checked approximately every 15 seconds and on manual refresh. Online status reflects TCP reachability only.

`LDCStatusCheckCompletion` serializes connection completion and timeout results with an actor so each probe completes once. Repository refreshes update stored statuses, then reload current records; an older snapshot cannot restore a removed device or lose a newly added one. Discovery scan and reverse-lookup result updates run on the main actor, and cancelled tasks do not publish their results.

## Remote commands

- `LDCProcessSSHClient` runs `/usr/bin/ssh` with `BatchMode=yes` for SSH key or agent authentication.
- `LDCExpectSSHClient` uses `/usr/bin/expect` for password authentication when the optional NMSSH module is absent.
- `LDCNMSSHClient` is compiled only when `canImport(NMSSH)` succeeds; it is not a bundled dependency.
- `LDCTerminalLauncher` creates an interactive Terminal session through AppleScript. That path uses Terminal's SSH configuration rather than the app's stored password or custom key path.

Power commands use `sudo` and `shutdown`. Failures that indicate a sudo password requirement create a prompt; other failures currently go to application logs.

## Persistence and host keys

The database remains at `~/Library/Application Support/SSHMacApp/devices.sqlite3` so installations from before the rename retain their devices. `SSHMacApp` here is a compatibility directory, not the current app name.

Records contain identity, address, port, username, authentication settings, status, and an optional plaintext password. Remembered sudo passwords share that password field. There is no Keychain integration or database encryption.

Host-key review uses `ssh-keyscan` and SHA-256 fingerprints. Saving records the connection policy, not the reviewed fingerprint. See [Security](../SECURITY.md) for the consequences and other current limitations.

## App assets

The app icon is a terminal connected to LAN devices. `LDCIconGenerator.swift` supplies vector artwork; the exporter renders the ten standard macOS raster slots into the asset catalog. Xcode packages the icon for Finder and the Dock. Regeneration instructions belong in [Development](development.md#app-icon).
