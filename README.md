# LanDeviceConnect

<img src="LanDeviceConnect/App/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="LanDeviceConnect icon" width="96" height="96" />

Manage SSH devices on your local network from one macOS app.

- Discover devices and see available hostnames and device details.
- Save connection settings and check whether devices are online.
- Open an SSH session in Terminal.
- Shut down or restart a device after confirming the action.

## Get started

You need macOS 13 or later, Xcode to build the app, and a remote device with SSH enabled.

1. Open [LanDeviceConnect.xcodeproj](LanDeviceConnect/LanDeviceConnect.xcodeproj) in Xcode.
2. Select the **LanDeviceConnect** scheme and **My Mac**, then run the app. Choose a signing team if Xcode requests one.
3. Click **+** or press **Command-N** to add a device.
4. Select a discovered device or enter its address, then supply your SSH username and authentication settings.
5. Click **Save** to return to your device list.

Use the Terminal icon to connect. The power icon offers **Shut Down…** and **Restart…**; both require confirmation. Use **Back**, **Cancel**, or **Escape** to leave Add Device without saving.

Discovery cannot identify every device. You can always add a host manually, including one that uses a different SSH port. “Online” means its SSH port responds; it does not verify your login.

## Passwords and privacy

Prefer SSH keys. Saved passwords, including remembered sudo passwords, are currently stored **without encryption** on your Mac. Read the [security notes](SECURITY.md) before using password authentication.

## More information

- [User guide](docs/user-guide.md): connections, discovery, and troubleshooting.
- [Development](docs/development.md): command-line builds, tests, and app icons.
- [Architecture](docs/architecture.md): how the app is organized.
- [Security](SECURITY.md): data handling, current limitations, and reporting concerns.

## License

[GNU General Public License, version 3](LICENSE).
