ssh_mac_app (SwiftUI macOS)

Overview
- SwiftUI macOS app to manage SSH-accessible devices on a LAN.
- Features: device list with reachability status, SSH actions (shutdown/restart), open in Terminal, add devices (manual + Bonjour discovery), periodic status checks, SQLite persistence.

How to use
1) Open `SSHMacApp.xcodeproj` in Xcode.
2) Select the `SSHMacApp` scheme and a My Mac destination.
3) Update the Signing team under Target Settings > Signing & Capabilities, if needed.
4) Build & run.

Notes
- Persistence uses SQLite via the built-in `SQLite3` C library (`import SQLite3`).
- SSH actions by default use key-based auth via system `/usr/bin/ssh` to run commands. For password-based SSH, integrate a library:
  - NMSSH (CocoaPods/Carthage) or SwiftNIO SSH (SwiftPM). If NMSSH is available, the `NMSSHClient` implementation will be compiled automatically (guarded by `#if canImport(NMSSH)`).
- Status checks probe TCP:22 (SSH) via the `Network` framework (no raw ICMP), updating colors accordingly.
- Bonjour discovery browses `_ssh._tcp.` services; you can extend with ping sweep if desired.

Security
- For simplicity, credentials (including passwords) are stored in SQLite. For production, prefer Keychain for secrets and store only references in SQLite.

Structure
- App/
  - SSHMacAppApp.swift
- Models/
  - Device.swift
  - DeviceStatus.swift
- Services/
  - DeviceStore.swift
  - StatusChecker.swift
  - SSHClient.swift
  - TerminalLauncher.swift
  - DiscoveryService.swift
- ViewModels/
  - DeviceRepository.swift
- Views/
  - DeviceListView.swift
  - AddDeviceView.swift
  - Components/
    - StatusDot.swift
    - DeviceRowView.swift

Build settings
- Target platform: macOS 13+ recommended (works with macOS 12+ if Network framework usage is adjusted).
- Ensure your target links the `Network` framework and has `import AppKit` allowed (macOS app target default).

CLI builds
- Build once: `make build` (opens Xcode toolchain; macOS only)
- Run app: `make run`
- Clean: `make clean`
- Auto-build on changes (requires fswatch): `bash scripts/watch.sh`
