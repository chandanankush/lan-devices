# Repository security review

Review date: 2026-09-27. This review accompanied the public documentation cleanup.

## Scope and evidence

The review covered tracked source/configuration, documentation, the two legacy screenshots, and Git history reachable from local refs. Gitleaks 8.30.1 was obtained from its official release and checked against the published archive checksum. Its default rules reported no secrets across the 15 commits reachable from local refs.

A separate Gitleaks scan of 58 current tracked worktree and new documentation files prepared for publication also reported no secrets. Automated secret detection does not identify every kind of sensitive information, inspect screenshots visually, or establish runtime security.

The real device database, personal SSH files, running-device credentials, external release archives, remote-only refs, forks, and caches were not accessed or scanned. This was not a penetration test.

## Repository cleanup

| Finding | Change |
| --- | --- |
| Personal Xcode state was still tracked despite ignore rules | Removed it from tracking while preserving the local copies. |
| Legacy screenshots contained real device/account identifiers and outdated UI | Removed them from tracking and removed their README references; local originals remain available. |
| Generated build output, databases, and common secret files needed explicit protection | Extended repository ignore rules. |
| Two READMEs duplicated extensive implementation details | Replaced the main README with a short user introduction and made the application README a directory guide. |
| Technical and security facts were mixed into user setup | Moved them into User Guide, Development, Architecture, and Security documents. |
| An external legacy app archive was linked without a current artifact review | Removed the download reference. External archive contents remain outside this review. |

The old screenshots and Xcode state remain in earlier Git commits. Current-file cleanup does not erase that history. No history rewrite or remote artifact deletion was performed.

## Runtime limitations found in source

These are documented findings, not fixes made by the documentation change.

| Area | Current behavior | Hardening needed |
| --- | --- | --- |
| Secret storage | SQLite contains plaintext SSH and remembered sudo passwords | Keychain-backed secret storage and migration of existing records. |
| Password reuse | SSH and sudo passwords share a single field | Separate credential roles and storage references. |
| Host-key review | Scanned fingerprints are displayed but are not pinned | Persist verified keys and bind later connections to that verification. |
| Expect host-key handling | Unknown-host prompts are answered automatically | Enforce a consistent explicit trust policy across clients. |
| Command construction | Terminal/Expect paths construct commands from user-controlled values | Strong validation and escaping, with tests for shell, AppleScript, and Tcl boundaries. |
| Process data and logging | Password-bearing commands and remote error output may expose sensitive data | Avoid secrets in command arguments and redact error/log output. |

Code references: [device store](../LanDeviceConnect/Services/LDCDeviceStore.swift), [SSH clients](../LanDeviceConnect/Services/LDCSSHClient.swift), [Expect client](../LanDeviceConnect/Services/LDCExpectSSHClient.swift), [Terminal launcher](../LanDeviceConnect/Services/LDCTerminalLauncher.swift), [host-key form](../LanDeviceConnect/Views/LDCAddDeviceFormView.swift), and [repository](../LanDeviceConnect/ViewModels/LDCDeviceRepository.swift).

See [Security](../SECURITY.md) for the user-facing consequences and reporting instructions, and [Development](development.md#public-repository-hygiene) for publishing checks.
