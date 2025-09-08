import SwiftUI

@main
struct SSHMacAppApp: App {
    @StateObject private var repo = DeviceRepository()

    var body: some Scene {
        WindowGroup("Devices") {
            DeviceListView()
                .environmentObject(repo)
        }
        WindowGroup("Add Device", id: "add-device") {
            AddDeviceFlowView()
                .environmentObject(repo)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Device") {
                    repo.showAddDeviceSheet.toggle()
                }.keyboardShortcut("n")
            }
        }
    }
}
