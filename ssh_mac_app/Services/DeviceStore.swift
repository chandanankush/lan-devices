import Foundation
import SQLite3

final class DeviceStore {
    static let shared = DeviceStore()

    private let dbURL: URL
    private var db: OpaquePointer?

    private init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("SSHMacApp", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        dbURL = dir.appendingPathComponent("devices.sqlite3")
        open()
        createSchemaIfNeeded()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func open() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            if let cstr = sqlite3_errmsg(db) {
                print("[DeviceStore] Failed to open DB at \(dbURL.path): \(String(cString: cstr))")
            } else {
                print("[DeviceStore] Failed to open DB at \(dbURL.path)")
            }
        }
    }

    private func createSchemaIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            host TEXT NOT NULL,
            port INTEGER NOT NULL,
            username TEXT NOT NULL,
            password TEXT,
            use_password_auth INTEGER NOT NULL,
            ssh_key_path TEXT,
            accept_new_host_key INTEGER NOT NULL DEFAULT 0,
            status INTEGER NOT NULL
        );
        """
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err { print("[DeviceStore] schema error: \(String(cString: err))") }
        }
        // Migration: ensure accept_new_host_key exists
        let pragma = "PRAGMA table_info(devices);"
        var stmt: OpaquePointer?
        var hasAcceptNew = false
        if sqlite3_prepare_v2(db, pragma, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let colName = sqlite3_column_text(stmt, 1) {
                    if String(cString: colName) == "accept_new_host_key" { hasAcceptNew = true; break }
                }
            }
        }
        if !hasAcceptNew {
            let alter = "ALTER TABLE devices ADD COLUMN accept_new_host_key INTEGER NOT NULL DEFAULT 0;"
            if sqlite3_exec(db, alter, nil, nil, &err) != SQLITE_OK {
                if let err = err { print("[DeviceStore] alter error: \(String(cString: err))") }
            }
        }
    }

    func fetchAll() -> [Device] {
        var stmt: OpaquePointer?
        let sql = "SELECT id, name, host, port, username, password, use_password_auth, ssh_key_path, accept_new_host_key, status FROM devices ORDER BY name COLLATE NOCASE;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var devices: [Device] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(stmt, 0),
                  let nameText = sqlite3_column_text(stmt, 1),
                  let hostText = sqlite3_column_text(stmt, 2),
                  let userText = sqlite3_column_text(stmt, 4) else { continue }
            let idStr = String(cString: idText)
            let id = UUID(uuidString: idStr) ?? UUID()
            let name = String(cString: nameText)
            let host = String(cString: hostText)
            let port = Int(sqlite3_column_int(stmt, 3))
            let username = String(cString: userText)
            let password = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 5)) : nil
            let usePasswordAuth = sqlite3_column_int(stmt, 6) != 0
            let keyPath = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 7)) : nil
            let acceptNew = sqlite3_column_int(stmt, 8) != 0
            let statusRaw = Int(sqlite3_column_int(stmt, 9))
            let status = DeviceStatus(rawValue: statusRaw) ?? .unknown

            devices.append(Device(id: id, name: name, host: host, port: port, username: username, password: password, usePasswordAuth: usePasswordAuth, sshKeyPath: keyPath, acceptNewHostKey: acceptNew, status: status))
        }
        return devices
    }

    func upsert(_ d: Device) {
        var stmt: OpaquePointer?
        let sql = """
        INSERT INTO devices (id, name, host, port, username, password, use_password_auth, ssh_key_path, accept_new_host_key, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name=excluded.name,
          host=excluded.host,
          port=excluded.port,
          username=excluded.username,
          password=excluded.password,
          use_password_auth=excluded.use_password_auth,
          ssh_key_path=excluded.ssh_key_path,
          accept_new_host_key=excluded.accept_new_host_key,
          status=excluded.status;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bindDevice(d, to: stmt)
        if sqlite3_step(stmt) != SQLITE_DONE {
            if let c = sqlite3_errmsg(db) {
                print("[DeviceStore] upsert failed: \(String(cString: c))")
            } else {
                print("[DeviceStore] upsert failed")
            }
        }
    }

    func delete(id: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM devices WHERE id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[DeviceStore] delete failed")
        }
    }

    func updateStatus(id: UUID, status: DeviceStatus) {
        var stmt: OpaquePointer?
        let sql = "UPDATE devices SET status = ? WHERE id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(status.rawValue))
        sqlite3_bind_text(stmt, 2, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[DeviceStore] updateStatus failed")
        }
    }

    private func bindDevice(_ d: Device, to stmt: OpaquePointer?) {
        sqlite3_bind_text(stmt, 1, (d.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (d.name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, (d.host as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, Int32(d.port))
        sqlite3_bind_text(stmt, 5, (d.username as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let pw = d.password {
            sqlite3_bind_text(stmt, 6, (pw as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_int(stmt, 7, d.usePasswordAuth ? 1 : 0)
        if let kp = d.sshKeyPath {
            sqlite3_bind_text(stmt, 8, (kp as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_int(stmt, 9, d.acceptNewHostKey ? 1 : 0)
        sqlite3_bind_int(stmt, 10, Int32(d.status.rawValue))
    }
}

// sqlite3 transient lifetime helper
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
