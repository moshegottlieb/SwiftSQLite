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
    
    /// Intialize with a database path, ommit the path for a memory based database
    /// - Parameter path: Path (or URI) to the database file. The path `file::memory:` is used by default (in-memory database).
    /// - Throws: DatabaseError
    public init(path:String = "file::memory:") throws {
        var lhandle : OpaquePointer?
        let rc = sqlite3_open(path, &lhandle)
        defer {
            if rc != SQLITE_OK , let handle = lhandle {
                sqlite3_close(handle)
            }
        }
        try Database.check(rc,handle: lhandle)
        self.handle = lhandle!
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
    func exec(_ sql:String) throws {
        let stmt = try Statement(database: self, sql: sql)
        try stmt.step()
    }
    
    deinit {
        sqlite3_close(handle)
    }
    
    /// The last SQLite row ID
    /// ```
    /// try db.exec("CREATE TABLE auto_inc(id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT)")
    /// let stmt = try Statement(database: db, sql: "INSERT INTO auto_inc (value) VALUES ('Some text')")
    /// try stmt.step()
    /// let last_row_id = self.db.lastInsertRowId // last_row_id is > 0
    /// ```
    var lastInsertRowId : Int64 {
        return sqlite3_last_insert_rowid(handle)
    }
    
    
    internal static func check(_ rc:Int32,handle:OpaquePointer?) throws {
        guard  rc == SQLITE_OK else {
            guard let handle = handle else {
                throw DatabaseError(reason: "Unknown reason", code: rc)
            }
            throw DatabaseError(reason: String(cString: sqlite3_errmsg(handle)), code: rc)
        }
    }
    
    internal func check(_ rc:Int32) throws {
        try type(of: self).check(rc,handle: handle)
        
    }
    
    internal let handle: OpaquePointer
}
