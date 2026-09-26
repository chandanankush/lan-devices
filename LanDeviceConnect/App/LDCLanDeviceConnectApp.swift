import SwiftUI

@main
struct LDCLanDeviceConnectApp: App {
    @StateObject private var repo = LDCDeviceRepository()

    var body: some Scene {
        WindowGroup("Devices") {
            LDCDeviceListView()
                .environmentObject(repo)
        }
        .commands { LDCDeviceCommands() }
    }
}

private struct LDCDeviceCommands: Commands {
    @FocusedBinding(\.isAddingDevice) private var isAddingDevice: Bool?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Device") { isAddingDevice = true }
                .keyboardShortcut("n")
                .disabled(isAddingDevice == nil || isAddingDevice == true)
        }
    }
}
