import Foundation
import SQLite3

final class WorkspaceDatabase {
    let url: URL
    private var connection: OpaquePointer?
    private let lock = NSRecursiveLock()
    static let changeName = "com.twobitdev.iGet.workspace.changed"
    static var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.twobitdev.iGet")
    }
    static func defaultURL() throws -> URL {
        let root = try sharedContainer ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("iGet", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("workspace.sqlite")
    }
    init(url: URL) throws {
        self.url = url
        let result = sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK else {
            if let connection { sqlite3_close(connection) }
            connection = nil
            throw WorkspaceError.storage(L10n.text("Could not open the local database."))
        }
        do {
            sqlite3_busy_timeout(connection, 5000)
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=NORMAL")
            try execute("CREATE TABLE IF NOT EXISTS workspace (id INTEGER PRIMARY KEY CHECK(id = 1), document BLOB NOT NULL)")
            try execute("BEGIN IMMEDIATE")
            do {
                if try readUnlocked() == nil { try writeUnlocked(.initial) }
                try execute("COMMIT")
            } catch { try? execute("ROLLBACK"); throw error }
        } catch { sqlite3_close(connection); connection = nil; throw error }
    }
    deinit { sqlite3_close(connection) }
    func read() throws -> WorkspaceDocument {
        lock.lock()
        defer { lock.unlock() }
        guard let document = try readUnlocked() else { throw WorkspaceError.invalidData }
        try document.validate()
        return document
    }
    @discardableResult
    func update(_ change: (inout WorkspaceDocument) throws -> Void) throws -> WorkspaceDocument {
        lock.lock()
        defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            guard var document = try readUnlocked() else { throw WorkspaceError.invalidData }
            document.focus.reconcile()
            try change(&document)
            try document.validate()
            try writeUnlocked(document)
            try execute("COMMIT")
            return document
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func readUnlocked() throws -> WorkspaceDocument? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, "SELECT document FROM workspace WHERE id = 1", -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE { return nil }
        guard result == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else { throw failure() }
        let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        return try JSONDecoder().decode(WorkspaceDocument.self, from: data)
    }
    private func writeUnlocked(_ document: WorkspaceDocument) throws {
        let data = try JSONEncoder().encode(document)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, "INSERT OR REPLACE INTO workspace (id, document) VALUES (1, ?)", -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = data.withUnsafeBytes { bytes in sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(bytes.count), transient) }
        guard result == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }
    private func failure() -> WorkspaceError {
        WorkspaceError.storage(connection.map { String(cString: sqlite3_errmsg($0)) } ?? L10n.text("Database unavailable."))
    }
}
