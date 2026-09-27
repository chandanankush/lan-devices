# Contributing to LanDeviceConnect

Start with the [user guide](docs/user-guide.md), [development guide](docs/development.md), and [security limits](SECURITY.md). Use [Discussions](https://github.com/chandanankush/lan-devices/discussions) for setup questions; check existing issues and comment before starting a task.

## Small, focused contributions

[Good first issues](https://github.com/chandanankush/lan-devices/labels/good%20first%20issue) contain bounded tasks. [Help wanted](https://github.com/chandanankush/lan-devices/labels/help%20wanted) contains broader compatibility/usability requests. State the macOS version and commit you actually tried, and avoid generalizing beyond that evidence.

Create a branch, keep the PR scoped, explain the behavior or documentation changed, and update relevant guides. Preserve GPL-3.0 licensing and attribution.

## Safe validation

From the repository root, `make test` runs standalone logic tests with an in-memory device store and local network fixtures. For a full unsigned build, use the exact `xcodebuild` command in [development](docs/development.md#build-and-run).

Manual UI checks need disposable example records and a recording SSH client. Do not exercise shutdown/restart on active devices. Do not save test credentials into a personal database or share device inventories. Use `demo-device.local`, `demo`, and documentation address `192.0.2.10` in public examples.

Before publishing, review the diff, asset metadata, and screenshots for private data. Follow the [public repository hygiene guide](docs/development.md#public-repository-hygiene). Do not commit build products, signing settings, device databases, passwords, or private keys.

Keep feedback respectful and specific. Report security concerns through the private channels described in [SECURITY.md](SECURITY.md#report-a-concern).
