import SwiftUI

struct LDCDeviceListView: View {
    @EnvironmentObject var repo: LDCDeviceRepository
    @State private var isAddingDevice = false

    var body: some View {
        Group {
            if isAddingDevice {
                LDCAddDeviceFlowView(onFinish: { isAddingDevice = false })
            } else {
                deviceList
            }
        }
        .frame(minWidth: 720, minHeight: 440)
        .focusedSceneValue(\.isAddingDevice, $isAddingDevice)
    }

    private var deviceList: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(repo.devices) { device in
                    LDCDeviceRowView(device: device)
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
            LDCSudoPasswordPromptView(
                device: req.device,
                action: req.action,
                onSubmit: { password, remember in
                    Task { await repo.submitSudoPassword(password, remember: remember) }
                },
                onCancel: { repo.sudoRequest = nil }
            )
        }
        .navigationTitle("Devices")
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

private extension LDCDeviceListView {
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        SwiftUI.ToolbarItem(placement: .automatic) {
            Button { isAddingDevice = true } label: { Image(systemName: "plus") }
                .help("Add Device")
                .accessibilityLabel("Add Device")
        }
        SwiftUI.ToolbarItem(placement: .automatic) {
            Button { repo.refreshStatuses() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh Status")
        }
    }
}

// Command-N routes within the focused scene rather than changing every open window.
private struct LDCAddDeviceFocusKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isAddingDevice: Binding<Bool>? {
        get { self[LDCAddDeviceFocusKey.self] }
        set { self[LDCAddDeviceFocusKey.self] = newValue }
    }
}
