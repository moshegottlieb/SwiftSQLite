//
//  Database.swift
//  
//
//  Created by Moshe Gottlieb on 18.08.20.
//

import Foundation
import SQLite3

/// SQLite database handle wrapper
public class Database {
    
    /// Set a default logger
    public static var logger: Log?
    
    /// Open mode
    public struct OpenMode : OptionSet {
        public init(rawValue:Int32){
            self.rawValue = rawValue
        }
        public let rawValue: Int32
        
        
        /// The database is opened in read-only mode. If the database does not already exist, an error is returned.
        public static let readOnly = OpenMode(rawValue: SQLITE_OPEN_READONLY)
        /// The database is opened for reading and writing if possible, or reading only if the file is write protected by the operating system. In either case the database must already exist, otherwise an error is returned.
        public static let readWrite = OpenMode(rawValue: SQLITE_OPEN_READWRITE)
        /// The database is opened for reading and writing, and is created if it does not already exist.
        public static let create = OpenMode(rawValue: SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
    }
    
    /// Threading model for database open
    public enum ThreadingModel{
        /// The new database connection will use the "multi-thread" threading mode. This means that separate threads are allowed to use SQLite at the same time, as long as each thread is using a different database connection.
        case noMutex
        /// The new database connection will use the "serialized" threading mode. This means the multiple threads can safely attempt to use the same database connection at the same time. (Mutexes will block any actual concurrency, but in this mode there is no harm in trying.)
        case fullMutex
        
        internal var flag : Int32 {
            switch self {
            case .noMutex:
                return SQLITE_OPEN_NOMUTEX
            case .fullMutex:
                return SQLITE_OPEN_FULLMUTEX
            }
        }
    }
    
    /// Intialize with a database path, ommit the path for a memory based database
    /// - Parameters:
    ///   - path: Path (or URI) to the database file. The path `file::memory:` is used by default (in-memory database).
    ///   - mode: Open mode
    ///   - logger: An optional logger
    /// - Throws: DatabaseError
    public init(path:String = ":memory:",mode:OpenMode = .create, threading:ThreadingModel = .fullMutex) throws {
        try open(path:path,mode:mode,threading: threading)
    }
    
    /// Opens a new databae connection, the old connection is closed if open
    /// - Parameters:
    ///   - path: Path (or URI) to the database file. The path `file::memory:` is used by default (in-memory database).
    ///   - mode: Open mode
    /// - Throws: DatabaseError
    public func open(path:String = ":memory:",mode:OpenMode = .create, threading:ThreadingModel = .fullMutex) throws {
        close()
        var lhandle : OpaquePointer?
        let rc = sqlite3_open_v2(path, &lhandle, mode.rawValue | threading.flag ,nil)
        defer {
            if rc != SQLITE_OK , let handle = lhandle {
                sqlite3_close(handle)
            }
        }
        try Database.check(rc,handle: lhandle)
        self.handle = lhandle
        logger?.log(message: "Opened database: \(path)")
    }
    
    /// A convenience utility to create a new statement
    /// - Parameter sql: SQL statement
    /// - Throws: DatabaseError
    /// - Returns: A new statement associated with this database connection
    public func statement<S:Statement>(sql:String) throws -> S {
        return try S(database: self, sql: sql)
    }
    
    /// Transaction journal mode - see [original documentation](https://www.sqlite.org/pragma.html#pragma_journal_mode) at the SQLite website
    public enum JournalMode : String {
        /// The DELETE journaling mode is the normal behavior. In the DELETE mode, the rollback journal is deleted at the conclusion of each transaction. Indeed, the delete operation is the action that causes the transaction to commit. (See the document titled Atomic Commit In SQLite for additional detail.)
        case delete
        /// The TRUNCATE journaling mode commits transactions by truncating the rollback journal to zero-length instead of deleting it. On many systems, truncating a file is much faster than deleting the file since the containing directory does not need to be changed.
        case truncate
        /// The PERSIST journaling mode prevents the rollback journal from being deleted at the end of each transaction. Instead, the header of the journal is overwritten with zeros. This will prevent other database connections from rolling the journal back. The PERSIST journaling mode is useful as an optimization on platforms where deleting or truncating a file is much more expensive than overwriting the first block of a file with zeros. See also: (PRAGMA journal_size_limit)[https://www.sqlite.org/pragma.html#pragma_journal_size_limit] and [SQLITE_DEFAULT_JOURNAL_SIZE_LIMIT](https://www.sqlite.org/compile.html#default_journal_size_limit).
        case persist
        /// The MEMORY journaling mode stores the rollback journal in volatile RAM. This saves disk I/O but at the expense of database safety and integrity. If the application using SQLite crashes in the middle of a transaction when the MEMORY journaling mode is set, then the database file will very likely [go corrupt](https://www.sqlite.org/howtocorrupt.html#cfgerr).
        case memory
        /// The WAL journaling mode uses [a write-ahead log](https://www.sqlite.org/wal.html) instead of a rollback journal to implement transactions. The WAL journaling mode is persistent; after being set it stays in effect across multiple database connections and after closing and reopening the database. A database in WAL journaling mode can only be accessed by SQLite version 3.7.0 (2010-07-21) or later.
        case wal
        /// The OFF journaling mode disables the rollback journal completely. No rollback journal is ever created and hence there is never a rollback journal to delete. The OFF journaling mode disables the atomic commit and rollback capabilities of SQLite. The ROLLBACK command no longer works; it behaves in an undefined way. Applications must avoid using the ROLLBACK command when the journal mode is OFF. If the application crashes in the middle of a transaction when the OFF journaling mode is set, then the database file will very likely go corrupt. Without a journal, there is no way for a statement to unwind partially completed operations following a constraint error. This might also leave the database in a corrupted state. For example, if a duplicate entry causes a CREATE UNIQUE INDEX statement to fail half-way through, it will leave behind a partially created, and hence corrupt, index. Because OFF journaling mode allows the database file to be corrupted using ordinary SQL, it is disabled when SQLITE_DBCONFIG_DEFENSIVE is enabled.
        case off
    }
    
    /// Unfortunately, it is not possible to use prepared statement parameters for the statement name
    /// - Parameters:
    ///   - template: A string format containing a single %@ sequence, to be replaced with the schema identifier if available
    ///   - schema: Optional schema name
    /// - Returns: An SQL statement with or without a schema
    private func schemaStatement(template:String,schema:String?) -> String{
        let schema_prefix:String
        if let schema = schema {
            schema_prefix = schema.appending(".")
        } else {
            schema_prefix = ""
        }
        return String(format:template,schema_prefix)
    }
    
    /// Return the current [journal mode](https://www.sqlite.org/pragma.html#pragma_journal_mode)
    ///
    /// **Warning**: Never use user input for the schema name, as it would expose your queries to SQL injection attacks
    /// - Parameter schema: Optional schema name
    /// - Throws: DatabaseError
    /// - Returns: See `JournalMode` for a list of valid values
    public func journalMode(schema:String? = nil) throws -> JournalMode {
        let sql = schemaStatement(template: "PRAGMA %@journal_mode", schema: schema)
        let stmt = try statement(sql: sql)
        guard try stmt.step(), let mode = stmt.string(column: 0) else {
            throw DatabaseError(reason: "Could not fetch journal mode", code: -1)
        }
        guard let ret = JournalMode(rawValue: mode.lowercased()) else {
            throw DatabaseError(reason: "Unknown journal mode: \(mode)", code: -1)
        }
        return ret
    }
    
    /// Set the current [journal mode](https://www.sqlite.org/pragma.html#pragma_journal_mode)
    ///
    /// **Warning**: Never use user input for the schema name, as it would expose your queries to SQL injection attacks
    /// - Parameters:
    ///   - journalMode: See `JournalMode` for a list of possible values
    ///   - schema: Optional schema name
    /// - Throws: DatabaseError
    public func set(journalMode:JournalMode,schema:String? = nil) throws {
        let sql = schemaStatement(template: "PRAGMA %@journal_mode = \(journalMode.rawValue)", schema: schema)
        try exec(sql)
    }
    
    /// Easy wrapper to prepare and execute an SQL statement
    /// - Parameter sql: SQL statement
    /// - Throws: DatabaseError
    public func exec(_ sql:String) throws {
        logger?.log(sql: sql)
        try check(sqlite3_exec(handle, sql, nil, nil, nil))
    }
    
    /// Set to `true` to enforce foreign keys, or `false` to disable foreign keys. See [PRAGMA foreign_keys](https://sqlite.org/pragma.html#pragma_foreign_keys) for more information.
    public var foreignKeys : Bool {
        set {
            let sql = "PRAGMA foreign_keys = \(newValue ? "true" : "false")"
            try! exec(sql)
        }
        get {
            let stmt = try! statement(sql: "PRAGMA foreign_keys")
            guard try! stmt.step() else {
                fatalError("Could not get foreign keys pragma value")
            }
            return stmt.bool(column: 0)!
        }
    }
    
    /// Enable or disable recursive triggers. See [PRAGMA recursive_triggers](https://www.sqlite.org/pragma.html#pragma_recursive_triggers) for more information.
    public var recursiveTriggers : Bool {
        set {
            let sql = "PRAGMA recursive_triggers = \(newValue ? "true" : "false");"
            try! exec(sql)
        }
        get {
            let stmt = try! statement(sql: "PRAGMA recursive_triggers")
            guard try! stmt.step() else {
                fatalError("Could not get recursive triggers pragma value")
            }
            return stmt.bool(column: 0)!
        }
    }
    
    /// A wrapper for `withForeignKeys<R>(on:Bool, exec:() throws ->R) rethrows -> R`, with an ON value, use to perform code with foreign keys support turned on
    /// - Parameter exec: A code block that may throw, and may return any value
    /// - Throws: Rethrows errors thrown from the code block
    /// - Returns: Returns the return value of the code block
    public func withForeignKeys<R>(exec:() throws ->R) rethrows -> R{
        return try withForeignKeys(on: true, exec: exec)
    }
    /// A wrapper for `withForeignKeys<R>(on:Bool, exec:() throws ->R) rethrows -> R`, with an OFF value, use to perform code with foreign keys support turned off
    /// - Parameter exec: A code block that may throw, and may return any value
    /// - Throws: Rethrows errors thrown from the code block
    /// - Returns: Returns the return value of the code block
    public func withoutForeignKeys<R>(exec:() throws ->R) rethrows -> R{
        return try withForeignKeys(on: false, exec: exec)
    }
    
    /// Run a code block with or without foreign key enforcement, the original state is restored at the end of the code block
    /// - Parameters:
    ///   - on: `true` to enforce foreign keys, `false` to ignore foreign keys
    ///   - exec: A code block that may throw, and may return any value
    /// - Throws: Rethrows errors thrown from the code block
    /// - Returns: Returns the return value of the code block
    public func withForeignKeys<R>(on:Bool, exec:() throws ->R) rethrows -> R{
        let current = foreignKeys
        guard on != current else {
            return try exec() // no need to change anything
        }
        foreignKeys = current ? false : true
        defer {
            foreignKeys = current
        }
        return try exec()
    }
    
    
    /// Use the JSON1 extension for JSON values, currently it means that codable will use JSONs as strings, and not data.
    public var useJSON1 = true
    
    /// Set auto vacuum mode, auto-vacuuming is only possible if the database stores some additional information that allows each database page to be traced backwards to its referrer. Therefore, auto-vacuuming must be turned on before any tables are created. It is not possible to enable or disable auto-vacuum after a table has been created.
    public enum AutoVacuum : Int{
        /// The default setting for auto-vacuum is 0 or "none", unless the SQLITE_DEFAULT_AUTOVACUUM compile-time option is used. The "none" setting means that auto-vacuum is disabled. When auto-vacuum is disabled and data is deleted data from a database, the database file remains the same size. Unused database file pages are added to a "freelist" and reused for subsequent inserts. So no database file space is lost. However, the database file does not shrink. In this mode the VACUUM command can be used to rebuild the entire database file and thus reclaim unused disk space.
        case none = 0
        /// When the auto-vacuum mode is 1 or "full", the freelist pages are moved to the end of the database file and the database file is truncated to remove the freelist pages at every transaction commit. Note, however, that auto-vacuum only truncates the freelist pages from the file. Auto-vacuum does not defragment the database nor repack individual database pages the way that the VACUUM command does. In fact, because it moves pages around within the file, auto-vacuum can actually make fragmentation worse.
        case full = 1
        /// When the value of auto-vacuum is 2 or "incremental" then the additional information needed to do auto-vacuuming is stored in the database file but auto-vacuuming does not occur automatically at each commit as it does with auto_vacuum=full. In incremental mode, the separate incremental_vacuum pragma must be invoked to cause the auto-vacuum to occur (See `func incrementalVacuum(pages:Int? = nil,schema:String? = nil) throws`)
        /// - SeeAlso: `incrementalVacuum`
        case incremental = 2
    }
    
    /// Set auto vacuum mode
    /// - SeeAlso: `AutoVacuum`
    /// - Parameters:
    ///   - autoVacuum: Auto vacuum mode
    ///   - schema: Optional scheme
    /// - Throws: DatabaseError
    public func set(autoVacuum:AutoVacuum,schema:String? = nil) throws {
        let sql = schemaStatement(template: "PRAGMA %@auto_vacuum = \(autoVacuum.rawValue)", schema: schema)
        try exec(sql)
    }
    /// Get current auto vacuum mode
    /// - Parameter schema: Optional schema
    /// - Throws: DatabaseError
    /// - Returns: AutoVacuum mode
    public func autoVacuum(schema:String? = nil) throws -> AutoVacuum{
        let sql = schemaStatement(template: "PRAGMA %@auto_vacuum", schema: schema)
        let stmt = try statement(sql: sql)
        guard try stmt.step() else {
            throw DatabaseError(reason: "Error fetching auto vacuum, step failed", code: -1)
        }
        return AutoVacuum(rawValue: stmt.integer(column: 0) ?? 0) ?? .none
    }
    /// The incremental_vacuum pragma causes up to N pages to be removed from the freelist. The database file is truncated by the same amount. The incremental_vacuum pragma has no effect if the database is not in auto_vacuum=incremental mode or if there are no pages on the freelist. If there are fewer than N pages on the freelist, or if N is less than 1, or if the "(N)" argument is omitted, then the entire freelist is cleared.
    /// - Parameters:
    ///   - pages: Number of pages to remove, 0 or nil will clear the entire free list
    ///   - schema: Optional schema
    /// - Throws: DatabaseError
    public func incrementalVacuum(pages:Int? = nil,schema:String? = nil) throws {
        let sql:String
        if let pages = pages {
            sql = schemaStatement(template: "PRAGMA %@incremental_vacuum(\(pages))", schema: schema)
        } else {
            sql = schemaStatement(template: "PRAGMA %@incremental_vacuum", schema: schema)
        }
        try exec(sql)
    }
    
    /// Manually vacuum the database
    /// It's important to keep your room neat and tidy! vacuum from time to time to reclaim unused pages, caused by deletes, this call vacuums some pages that cannot be reclaimed with auto vacuum.
    /// - Parameters:
    ///   - schema:Optional schema
    ///   - into: Optional new database path, if provided, a new vacuumed database will be created in the provided path
    /// - Throws: DatabaseError
    public func vacuum(schema:String? = nil,into:String? = nil) throws {
        let sql:String
        if let into = into {
            let into_escaped = into.replacingOccurrences(of: "'", with: "''")
            sql = schemaStatement(template: "VACUUM %@ INTO '\(into_escaped)'", schema: schema)
        } else {
            sql = schemaStatement(template: "VACUUM %@", schema: schema)
        }
        try exec(sql)
    }
    
    /// Set the busy timeout, useful for WAL mode. See [sqlite3_busy_timeout()](https://sqlite.org/c3ref/busy_timeout.html)
    /// - Parameter ms: Milleseconds for timeout
    /// - Throws: DatabaseError
    public func set(busyTimeout ms:Int) throws {
        try check(sqlite3_busy_timeout(self.handle,Int32(ms)))
    }
    
    /// Close a database connection
    public func close(){
        guard handle != nil else { return }
        sqlite3_close(handle)
        handle = nil
        logger?.log(message: "Closed database")
    }
    
    deinit {
        close()
    }
    
    /// The last SQLite row ID
    /// ```
    /// try db.exec("CREATE TABLE auto_inc(id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT)")
    /// let stmt = try Statement(database: db, sql: "INSERT INTO auto_inc (value) VALUES ('Some text')")
    /// try stmt.step()
    /// let last_row_id = self.db.lastInsertRowId // last_row_id is > 0
    /// ```
    public var lastInsertRowId : Int64 {
        return sqlite3_last_insert_rowid(handle)
    }
    
    /// Version type - see set(version:,for:,schema:)
    public enum Version : String {
        /// See [PRAGMA data_version](https://sqlite.org/pragma.html#pragma_data_version)
        case data = "data_version"
        /// See [PRAGMA schema_version](https://sqlite.org/pragma.html#pragma_schema_version)
        case schema = "schema_version"
        /// See [PRAGMA user_version](https://sqlite.org/pragma.html#pragma_user_version)
        case user = "user_version"
    }
    
    /// Set user version
    /// - Parameters:
    ///   - version: Version numeric value
    ///   - schema: Optional schema
    /// - Throws: DatabaseError
    public func set(version:Int,schema:String? = nil) throws {
        let sql:String
        sql = schemaStatement(template: "PRAGMA %@user_version = \(version)", schema: schema)
        try exec(sql)
    }
    
    /// Get version integer value
    /// - Parameters:
    ///   - version: Version type (`user`, by default)
    ///   - schema: Optional schema
    /// - Throws: DatabaseError
    /// - Returns: Version integer value
    public func get(version:Version,schema:String? = nil) throws -> Int {
        let sql:String
        sql = schemaStatement(template: "PRAGMA %@\(version.rawValue)", schema: schema)
        let stmt = try statement(sql: sql)
        guard try stmt.step() else {
            throw DatabaseError(reason: "Error fetching version",code:-1)
        }
        return stmt.integer(column: 0)!
    }
    
    /// See [Checkpoint a database](https://sqlite.org/c3ref/wal_checkpoint_v2.html)
    public enum CheckpointMode {
        /// Checkpoint as many frames as possible without waiting for any database readers or writers to finish, then sync the database file if all frames in the log were checkpointed. The busy-handler callback is never invoked in the SQLITE_CHECKPOINT_PASSIVE mode. On the other hand, passive mode might leave the checkpoint unfinished if there are concurrent readers or writers.
        case passive// = SQLITE_CHECKPOINT_PASSIVE
        /// This mode blocks (it invokes the busy-handler callback) until there is no database writer and all readers are reading from the most recent database snapshot. It then checkpoints all frames in the log file and syncs the database file. This mode blocks new database writers while it is pending, but new database readers are allowed to continue unimpeded.
        case full// = SQLITE_CHECKPOINT_FULL
        case restart// = SQLITE_CHECKPOINT_RESTART
        //This mode works the same way as SQLITE_CHECKPOINT_FULL with the addition that after checkpointing the log file it blocks (calls the busy-handler callback) until all readers are reading from the database file only. This ensures that the next writer will restart the log file from the beginning. Like SQLITE_CHECKPOINT_FULL, this mode blocks new database writer attempts while it is pending, but does not impede readers.
        case truncate// = SQLITE_CHECKPOINT_TRUNCATE
        
        internal var sqliteValue : Int32 {
            switch self {
            case .full:
                return SQLITE_CHECKPOINT_FULL
            case .passive:
                return SQLITE_CHECKPOINT_PASSIVE
            case .restart:
                return SQLITE_CHECKPOINT_RESTART
            case .truncate:
                return SQLITE_CHECKPOINT_TRUNCATE
            }
        }
    }
    
    public func walCheckpoint(mode:CheckpointMode = .passive) throws {
        try check(sqlite3_wal_checkpoint_v2(handle, nil, mode.sqliteValue, nil, nil))
    }
    
    internal static func check(_ rc:Int32,handle:OpaquePointer?) throws {
        guard  rc == SQLITE_OK else {
            let reason:String
            if let handle = handle {
                reason = String(cString: sqlite3_errmsg(handle))
            } else {
                reason = "Unknown reason"
            }
            logger?.log(error: reason,code: Int(rc))
            throw DatabaseError(reason: reason, code: rc)
        }
    }
    
    internal func check(_ rc:Int32) throws {
        try type(of: self).check(rc,handle: handle)
    }
    
    public var encoder = JSONEncoder()
    public var decoder = JSONDecoder()
    internal var logger : Log? {
        return type(of: self).logger
    }
    internal var handle: OpaquePointer?
}

// https://stackoverflow.com/questions/26883131/sqlite-transient-undefined-in-swift
internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
