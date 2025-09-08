import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var repo: DeviceRepository
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(repo.devices) { device in
                    DeviceRowView(device: device)
                        .environmentObject(repo)
                        .contextMenu {
                            Button("Open in Terminal") { repo.openInTerminal(device) }
                            Button("Restart") { Task { await repo.restart(device) } }
                            Button("Shutdown") { Task { await repo.shutdown(device) } }
                            Divider()
                            Button(role: .destructive) { repo.remove(device) } label: { Text("Delete") }
                        }
                }
            }
        }
        .toolbar(content: toolbarContent)
        .sheet(item: $repo.sudoRequest) { req in
            SudoPasswordPromptView(
                device: req.device,
                action: req.action,
                onSubmit: { password, remember in
                    Task { await repo.submitSudoPassword(password, remember: remember) }
                },
                onCancel: { repo.sudoRequest = nil }
            )
        }
        .onChange(of: repo.showAddDeviceSheet) { newValue in
            if newValue { openWindow(id: "add-device"); repo.showAddDeviceSheet = false }
        }
        .onAppear { repo.refreshStatuses() }
    }

    private var header: some View {
        HStack {
            Text("Devices").font(.largeTitle).bold()
            Spacer()
            if repo.isRefreshing { ProgressView().scaleEffect(0.7) }
        }
        .padding([.top, .horizontal])
    }
}

private extension DeviceListView {
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        SwiftUI.ToolbarItem(placement: .automatic) {
            Button { openWindow(id: "add-device") } label: { Image(systemName: "plus") }
                .help("Add Device")
        }
        SwiftUI.ToolbarItem(placement: .automatic) {
            Button { repo.refreshStatuses() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh Status")
        }
    }
}
