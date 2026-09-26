import SwiftUI

@main
struct LDCLanDeviceConnectApp: App {
    @StateObject private var repo = LDCDeviceRepository()

    var body: some Scene {
        WindowGroup("Devices") {
            LDCDeviceListView()
                .environmentObject(repo)
        }
        WindowGroup("Add Device", id: "add-device") {
            LDCAddDeviceFlowView()
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
