import SwiftUI

struct LDCDeviceListView: View {
    @EnvironmentObject var repo: LDCDeviceRepository
    @State private var isAddingDevice = false
    @State private var pendingPowerAction: LDCPowerActionRequest?

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
                    LDCDeviceRowView(device: device, onPowerAction: { action in
                        pendingPowerAction = LDCPowerActionRequest(device: device, action: action)
                    })
                        .environmentObject(repo)
                        .contextMenu {
                            Button("Open in Terminal") { repo.openInTerminal(device) }
                            Button("Shut Down…", role: .destructive) {
                                pendingPowerAction = LDCPowerActionRequest(device: device, action: .shutdown)
                            }
                            Button("Restart…") {
                                pendingPowerAction = LDCPowerActionRequest(device: device, action: .restart)
                            }
                            Divider()
                            Button(role: .destructive) { repo.remove(device) } label: { Text("Delete") }
                        }
                }
            }
        }
        .toolbar(content: toolbarContent)
        .alert(
            pendingPowerAction.map { "\($0.title) \($0.device.name)?" } ?? "Power Action",
            isPresented: Binding(
                get: { pendingPowerAction != nil },
                set: { if !$0 { pendingPowerAction = nil } }
            ),
            presenting: pendingPowerAction
        ) { request in
            Button("Cancel", role: .cancel) { pendingPowerAction = nil }
            Button(request.title, role: .destructive) {
                pendingPowerAction = nil
                Task {
                    switch request.action {
                    case .shutdown: await repo.shutdown(request.device)
                    case .restart: await repo.restart(request.device)
                    }
                }
            }
        } message: { request in
            Text("This will \(request.action == .shutdown ? "shut down" : "restart") the remote device at \(request.device.host):\(String(request.device.port)). Active sessions will disconnect.")
        }
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

private struct LDCPowerActionRequest {
    let device: LDCDevice
    let action: LDCDeviceAction

    var title: String { action == .shutdown ? "Shut Down" : "Restart" }
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
