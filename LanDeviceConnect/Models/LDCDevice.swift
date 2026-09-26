import Foundation

struct LDCDevice: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String?
    var usePasswordAuth: Bool
    var sshKeyPath: String?
    var acceptNewHostKey: Bool
    var status: LDCDeviceStatus

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        password: String? = nil,
        usePasswordAuth: Bool = false,
        sshKeyPath: String? = nil,
        acceptNewHostKey: Bool = false,
        status: LDCDeviceStatus = .unknown
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.usePasswordAuth = usePasswordAuth
        self.sshKeyPath = sshKeyPath
        self.acceptNewHostKey = acceptNewHostKey
        self.status = status
    }
}
