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
