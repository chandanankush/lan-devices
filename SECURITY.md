# Security

LanDeviceConnect controls remote devices through SSH. Use it only with devices and accounts you are authorized to manage. The current implementation has the limitations below; this project does not claim a completed security audit or hardened credential handling.

## Passwords and local data

Prefer SSH keys or an SSH agent over saved passwords.

Device records are stored at:

```text
~/Library/Application Support/SSHMacApp/devices.sqlite3
```

The legacy directory name preserves existing installations. The database includes hostnames/IP addresses, usernames, key paths, connection settings, and **unencrypted passwords** when supplied. Remembered sudo passwords share the same password field as SSH passwords. The app does not currently use Keychain or encrypt its database.

Do not share this database, include it in a release, or attach it to an issue. Removing a device from the app does not guarantee removal from SQLite pages, backups, or other copies.

Passwords may also be present in generated sudo commands and process arguments, and command failures can include sensitive output in application logs. Avoid saved passwords on shared or untrusted systems.

## Host keys

The host-key screen displays fingerprints obtained with `ssh-keyscan`. A scan does not authenticate the device. Compare the result with a fingerprint obtained independently through a trusted channel.

The app does **not** pin the reviewed key or save that fingerprint into the device record. Later connections perform their own OpenSSH host-key handling. With first-connect trust enabled, system SSH paths use `StrictHostKeyChecking=accept-new`; that is not proof that the later key matches the one reviewed earlier.

The Expect client also automatically answers a host-key confirmation prompt. Turning off first-connect trust therefore does not currently enforce rejection of every unknown host across all clients. For sensitive connections, establish and verify known-host entries independently and avoid relying on this setting as a strict security boundary.

## Discovery and remote commands

Discovery names, addresses, and manufacturer/model values are information supplied by the network. They are identification hints, not proof of ownership or authenticity.

The power menu requires a device-specific confirmation before requesting shutdown or restart. Remote sudo permissions are still required. Confirmation reduces accidental actions; it does not validate the remote host or account privileges.

Terminal and Expect command construction currently needs stronger escaping and validation of user-controlled values. Treat device addresses, usernames, key paths, and credentials as trusted input; do not use this app as a hardened executor for arbitrary imported connection data.

The source contains no analytics or upload service. Discovery, DNS lookups, SSH commands, and interactive Terminal sessions still produce network traffic; configured DNS resolvers may receive hostname queries.

## Share information safely

Public examples should use invented names, username `demo`, and documentation addresses such as `192.0.2.10`. Remove real device identities, credentials, fingerprints, and local account paths from screenshots and logs.

The repository ignores common secret files, databases, build outputs, and personal Xcode state. Ignore rules do not erase Git history. If a real credential has been published, revoke or rotate it before following [GitHub's sensitive-data removal guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

## Report a concern

Use the repository's private **Report a vulnerability** option if GitHub makes it available. Otherwise, contact the maintainer through an established private channel. Do not post live credentials, device inventories, raw logs, or an exploitable private endpoint in a public issue.

Include the affected commit or version, a description of the issue, and reproduction steps using sanitized example data.

The [repository security review](docs/security-review.md) records what was checked during the documentation cleanup. It is a scoped review, not a guarantee that the app or every historical artifact is secure.
