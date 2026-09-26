# User guide

LanDeviceConnect manages devices that already have SSH enabled. It does not enable SSH or create accounts on remote devices.

## Add a device

1. Click **+** or press **Command-N**. Add Device opens inside the current window.
2. Click a discovered device to fill **Name**, **Host/IP**, and **Port**. You can click anywhere on its row or use the arrow keys. The selection remains highlighted while you edit the form.
3. Enter the SSH **Username**. For key authentication, enter the private-key path if needed, such as `~/.ssh/id_ed25519`. For password authentication, enable **Use password authentication** and enter the password. Read [Security](../SECURITY.md) before saving passwords.
4. When **Trust host key on first connect** is enabled, review the displayed fingerprint against a value obtained from the device owner through a trusted channel. The review has limitations described in [Host keys](../SECURITY.md#host-keys).
5. Click **Save**. The device list returns in the same window.

Use **Back**, **Cancel**, or **Escape** to leave without saving. Switching discovered devices changes only Name, Host/IP, and Port; your username and authentication choices stay intact. A brief accent fade marks the updated fields, unless Reduce Motion is enabled.

For manual entry, give the device a name and enter its hostname or IP address and SSH port. For example, `demo-device.local` or `192.0.2.10` illustrates the format; replace it with your own device's address. Port **22** is the usual default.

## Identify discovered devices

Names and manufacturer/model details appear when the device or network makes them available. Some devices show only an IP address. IP and Bonjour results for the same SSH endpoint share a row.

Use the sidebar refresh button to scan again. If a device remains absent, add it manually. Automatic subnet discovery checks port 22 and may miss devices on other network ranges or ports.

Background discovery updates do not overwrite your form edits. When only a reverse-DNS name is known, the app displays that name but keeps the scanned IP as the connection address.

## Connect in Terminal

Click the device's Terminal icon. macOS may ask you to allow LanDeviceConnect to control Terminal.

Terminal uses your normal OpenSSH configuration and may request authentication. The app does not forward its saved password or custom SSH key path to the interactive Terminal session.

## Check connection status

The app checks saved devices automatically, or you can use **Refresh Status**.

**Online** means a connection to the configured SSH port succeeded. **Offline** means that check failed. Neither result confirms whether your username, key, password, or sudo permissions are valid.

## Remove a saved device

Right-click its row and choose **Delete**. This removes the saved entry from the app; it does not change the remote device. For data-removal limitations, see [Security](../SECURITY.md#passwords-and-local-data).

## Shut down or restart

1. Click the device's power icon.
2. Choose **Shut Down…** or **Restart…**.
3. Check the device name and address in the confirmation, then confirm or choose **Cancel**.

The right-click menu uses the same confirmation. The remote account needs suitable sudo permissions. A successful power action disconnects active sessions.

If sudo requires a password, the app may prompt for it. **Remember this password for this device** saves it without encryption and uses the same stored password field as SSH authentication. Avoid remembering it when the SSH and sudo passwords differ.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Device is missing from discovery | SSH is enabled, both devices can reach each other, and the network permits discovery. Try manual entry. |
| Device shows only an IP address | Its hostname or device metadata may not be advertised. Give it a useful name manually. |
| Device is Offline | Address, port, firewall, network connection, and whether the remote device is awake. |
| Device is Online but login fails | Username, key or password, and the remote account's SSH access. |
| Terminal does not open a session | macOS Automation permission for Terminal and your normal SSH configuration. |
| Shutdown or restart fails | Remote sudo permissions and the account's credentials. Detailed errors currently appear in application logs rather than a dedicated result dialog. |
| Password commands fail to launch | The system Expect executable must be available. See [Development](development.md#requirements). |

When sharing a screenshot or log, remove real hostnames, usernames, addresses, passwords, and fingerprints. Use example devices instead.
