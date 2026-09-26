import Foundation

// Substitute only the persistent database so repository tests never touch saved devices.
@MainActor
final class LDCDeviceStore {
    static let shared = LDCDeviceStore()
    private var records: [LDCDevice] = []

    func fetchAll() -> [LDCDevice] { records.sorted { $0.name < $1.name } }

    func upsert(_ device: LDCDevice) {
        if let index = records.firstIndex(where: { $0.id == device.id }) {
            records[index] = device
        } else {
            records.append(device)
        }
    }

    func delete(id: UUID) { records.removeAll { $0.id == id } }

    func updateStatus(id: UUID, status: LDCDeviceStatus) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].status = status
        }
    }
}
