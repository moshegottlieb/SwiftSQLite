//
//  Statement.swift
//  
//
//  Created by Moshe Gottlieb on 18.08.20.
//

import Foundation
import SQLite3

/// SQL Statement
///
/// Used for executing SQL statements, including queries.
///
/// ```
///  let db = try Database() // memory based DB
///
///  try db.exec("CREATE TABLE demo(a INT)")
///  let insert = try Statement(database:db, sql:"INSERT INTO demo (a) VALUES (?)")
///  try insert.bind(param:1, 1)
///  try insert.step()
///  try insert.reset() // Reset the statement, so it's ready for reuse
///  try insert.bind(param:1, 2)
///  try insert.step()
///  let query = try Statement(database:db, sql:"SELECT a FROM demo")
///  while try query.step() {
///      guard let i = query.integer(column:0) else { fatalError("Expected a value") }
///      print("a: \(i)")
///  }
///  // Prints:
///  // a: 1
///  // a: 2
/// ```
public class Statement {
    
    /// Initialize a statement object
    /// - Parameters:
    ///   - database: Database connection
    ///   - sql: SQL statement
    /// - Throws: Throws a DatabaseError for SQLite errors, tyipcally for syntax errors
    required public init(database:Database,sql:String) throws {
        self.db = database
        self.sql = sql
        var stmt:OpaquePointer?
        try database.check(sqlite3_prepare_v2(database.handle, sql, -1, &stmt, nil))
        self.stmt = stmt!
        db.logger?.log(prepare: sql)
    }
    deinit {
        finalize()
    }
    
    /// Column type identifier
    /// The native type of the column can be identified using the method `type(column:Int) -> ColumnType`.
    /// It is still possible to cast data (where applicable) using a different accessor, for instance, it is possible to request an integer value as a string.
    public enum ColumnType {
        /// Column is a floating point value
        case double
        /// Column is a text value
        case string
        /// Column is a BLOB value
        case data
        /// Column is an integer value
        case integer
        /// Column is a null value, unfortunately, there is no way to retrieve the column type when the value is null.
        ///
        /// Example:
        /// ```
        /// try db.exec("CREATE TABLE demo(a INT)")
        /// try db.exec("INSERT INTO demo (a) VALUES (NULL)")
        /// let stmt = try Statement(database:db,sql:"SELECT a FROM demo")
        /// guard try stmt.step() else { fatalError("Expected one row") }
        /// let type = stmt.type(column:0) // equals .null, and not .integer
        /// ```
        case null
    }
    
    /// Get the column name
    /// - Parameter column: Column index (zero based)
    /// - Returns: The name of the column (if it exists)
    public func name(column:Int) -> String? {
        guard let ptr = sqlite3_column_name(stmt, Int32(column)) else { return nil }
        return String(cString: ptr)
    }
    /// Get the original table name for a coloum
    /// - Parameter column: Column index (zero based)
    /// - Returns: The name of the table owning this column (if it exists)
    public func tableName(column:Int) -> String? {
        guard let ptr = sqlite3_column_table_name(stmt, Int32(column)) else { return nil }
        return String(cString: ptr)
    }
    /// Get the original name of a column
    /// - Parameter column: Column index (zero based)
    /// - Returns: The name of the column, omitting aliases
    public func originName(column:Int) -> String? {
        guard let ptr = sqlite3_column_origin_name(stmt, Int32(column)) else { return nil }
        return String(cString: ptr)
    }
    
    /// Get the type of a column
    /// - Parameter column: Column index (zero based)
    /// - Returns: The column type of the current _value_
    public func type(column:Int) -> ColumnType {
        switch sqlite3_column_type(stmt, Int32(column)){
        case SQLITE_INTEGER:
            return .integer
        case SQLITE_FLOAT:
            return .double
        case SQLITE_BLOB:
            return .data
        case SQLITE_NULL:
            return .null
        case SQLITE_TEXT:
            fallthrough
        default:
            return .string
        }
    }
    
    /// Check if a certain value is null or not
    ///
    /// Normally, this is not required as the value accessors return optionals (by calling `isNull` internally)
    /// - Parameter column: Column index (zero based)
    /// - Returns: True if the column value is null, false if not
    public func isNull(column:Int) -> Bool {
        return sqlite3_column_type(stmt, Int32(column)) == SQLITE_NULL
    }
    
    /// Retrieve a column value as an integer
    /// - Parameter column: Column index (zero based)
    /// - Returns: Int value or nil, if the value is null
    public func integer(column:Int) -> Int? {
        guard let res = integer32(column: column) else { return nil }
        return Int(res)
    }
    
    /// Retrieve a column value as a date
    ///
    /// SQLite does not have a native date value, the number of milliseconds since 1970 is stored instead.
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Date or nil if the value is nil
    public func date(column:Int) -> Date? {
        guard !isNull(column: column) else { return nil }
        let value = sqlite3_column_int64(stmt, Int32(column))
        return Date(epoch: value)
    }
    
    /// Retrieve a column value as a boolean
    /// SQLite has no native BOOL value (though the keyword is accepted).
    /// A BOOL `true` value is evaluated for a non zero integer expression.
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Boolean value or nil, if the value is null
    public func bool(column:Int) -> Bool? {
        guard !isNull(column: column) else { return nil }
        return sqlite3_column_int(stmt,Int32(column)) != 0
    }
    
    /// Retrieve a value as a long integer
    ///
    /// Same as the `integer(..)` variant on 64 bit platforms
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Int64 value or nil, if the value is null
    public func integer64(column:Int) -> Int64? {
        guard !isNull(column: column) else { return nil }
        return sqlite3_column_int64(stmt, Int32(column))
    }
    
    /// Retrieve a value as an Int32
    ///
    /// Same as the `integer(..)` variant on 32 bit platforms
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Int32 value or nil, if the value is null
    public func integer32(column:Int) -> Int32? {
        guard !isNull(column: column) else { return nil }
        return sqlite3_column_int(stmt, Int32(column))
    }
    
    /// Retrieve a value as a string
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: String value or nil, if the value is null
    public func string(column:Int) -> String? {
        guard !isNull(column: column) else { return nil }
        return String(cString: sqlite3_column_text(stmt, Int32(column)))
    }
    
    /// Fetch and decode a JSON value, the value should be saved in either a data or string object, as defined in `Database.useJSON1`, **true** means use a string value, **false** means use a BLOB value.
    /// - Parameters:
    ///   - column: column: Column index (zero based)
    /// - Returns: A decoded instance, if not null AND a successful conversion exists
    public func object<O:Decodable>(column:Int) -> O? {
        guard !isNull(column: column) else { return nil }
        let data:Data?
        if db.useJSON1 {
            guard let str = string(column: column) else { return nil }
            data = str.data(using: .utf8)
        } else {
            data = self.data(column: column)
        }
        guard let cdata = data else { return nil }
        return try? db.decoder.decode(O.self, from: cdata)
    }
    
    /// Retrieve a value as a double
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Double value or nil, if the value is null
    public func double(column:Int) -> Double? {
        guard !isNull(column: column) else { return nil }
        return sqlite3_column_double(stmt, Int32(column))
    }
    /// Retrieve the number of columns of a query result
    ///
    ///  ```
    ///  let query = try Statement(database:db, sql:"SELECT 1,2,3")
    ///  try query.step()
    ///  let count = query.columns() // count is now 3
    ///  ```
    /// Available after the first `step(...)` call
    /// - Returns: Number of columns
    public func columns() -> Int {
        return Int(sqlite3_column_count(stmt))
    }
    
    /// Retrieve a BLOB value as a Data instance
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: Data value or nil, if the value is nil, the data value is copied, and therefore may outlive later `step(...)` calls
    public func data(column:Int) -> Data? {
        guard !self.isNull(column: column) else { return nil }
        let len = sqlite3_column_bytes(stmt, Int32(column))
        guard let ptr = sqlite3_column_blob(stmt, Int32(column)) else {
            fatalError("Expected a value")
        }
        return Data(bytes: ptr, count: Int(len))
    }
    
    /// Retrieve a UUID, please note that UUIDs are not really supported by sqlite, and are stored as plain text.
    /// - Parameter column: column: Column index (zero based)
    /// - Returns: UUID value
    public func uuid(column:Int) -> UUID? {
        guard let text = string(column: column) else { return nil }
        return UUID(uuidString: text)
    }
    
    /// Bind a nil value
    ///
    /// By default, the value is already bound to nil, however, this can be used for prepared statemts to re-bind a value.
    ///
    /// It is recommended to `clearBindings` after a `reset()` instead.
    /// - Parameter param: Parameter number (1 based), when omitted, the parameters are added by their order
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam) throws -> Self {
        let param = autoParamIndex(param)
        try check(sqlite3_bind_null(stmt, Int32(param)))
        return self
    }
    
    /// Bind an Int32 value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Int32 value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam,_ value:Int32?) throws -> Self{
        if let value = value {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_int(stmt, Int32(param), value))
        } else {
            return try bind(param: param)
        }
    }
    /// Bind an Int64 value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Int64 value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam,_ value:Int64?) throws -> Self {
        if let value = value {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_int64(stmt, Int32(param), value))
        } else {
            return try bind(param: param)
        }
    }
    
    /// Bind an encodable parameter, depending on the `Database.useJSON1` value, the data is either saved as a blob when `useJSON1` is **false** or string when it is set to **true** (default).
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: An encodable object
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind<V:Encodable>(param:Int = autoParam, _ value:V?) throws -> Self {
        if let value = value {
            let data = try db.encoder.encode(value)
            if self.db.useJSON1 {
                guard let json = String(data: data, encoding: .utf8) else {
                    throw DatabaseError(reason: "Error converting data to a UTF-8 string", code: -1)
                }
                return try bind(param: param,json)
            } else {
                return try bind(param:param,data)
            }
        } else {
            return try bind(param: param)
        }
    }
    
    /// Bind a date value to a statement
    ///
    /// SQLite has no built in date type, instead, the number of milliseconds since 1970 is stored.
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Date value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam,_ value:Date?) throws -> Self{
        if let epoch = value?.epoch {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_int64(stmt, Int32(param), epoch))
        } else {
            return try bind(param: param)
        }
    }
    /// Bind a Bool value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Bool value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam,_ value:Bool?) throws -> Self{
        if let value = value {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_int(stmt, Int32(param), value ? 1 : 0))
        } else {
            return try bind(param: param)
        }
    }
    
    /// Bind an Int value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Int value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam,_ value:Int?) throws -> Self{
        let value32:Int32?
        if let value = value {
            value32 = Int32(value)
        } else {
            value32 = nil
        }
        return try bind(param: param, value32)
    }
    
    /// Bind a string value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: String value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam, _ value:String?) throws -> Self{
        if let value = value {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_text(stmt, Int32(param), value, -1, SQLITE_TRANSIENT))
        } else {
            return try bind(param: param)
        }
    }
    
    /// Bind an Int32 double to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Double value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam, _ value:Double?) throws -> Self{
        if let value = value {
            let param = autoParamIndex(param)
            return try check(sqlite3_bind_double(stmt, Int32(param), value))
        } else {
            return try bind(param: param)
        }
    }
    
    /// Bind a data (BLOB) value to a statement
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: Data value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam, _ value:Data?) throws -> Self{
        if let value = value {
            return try value.withUnsafeBytes { (body:UnsafeRawBufferPointer) in
                let param = autoParamIndex(param)
                return try check(sqlite3_bind_blob(stmt, Int32(param), body.baseAddress, Int32(value.count), SQLITE_TRANSIENT))
            }
        } else {
            return try bind(param: param)
        }
    }
    
    /// Binds a uuid value to a statement, SQLite has no UUID support, so wer'e converting UUIDs to strings
    /// - Parameters:
    ///   - param: Parameter number (1 based), when omitted, the parameters are added by their order
    ///   - value: UUID value, or nil
    /// - Throws: DatabaseError
    /// - Returns: Self , so binds could be chained: `stmt.bind("a").bind("b").bind(object)`
    @discardableResult public func bind(param:Int = autoParam, _ value:UUID?) throws -> Self{
        return try bind(param: param, value?.uuidString)
    }
    
    /// Step a statement
    ///
    /// Step is used to perform the statement, or to retrieve the next row.
    /// - When performing a statement that requires parameters, call the `bind(..)` variants before calling step
    /// - Bound parameters are not cleared after `step()` or `reset()`
    /// - Step may return a generic error, to retreive the specifc error, call `reset()`, I'm sorry, that's the way the SQLite API works
    /// - Step automatically calls `reset` after iterating all rows in SQLite > 3.6.23.1, and if the [SQLITE_OMIT_AUTORESET](https://sqlite.org/compile.html#omit_autoreset) compilation flag is not set, but it's recommended to call `reset` before reusing the statement.
    /// - Throws: DatabaseError
    /// - Returns: True if a row is available for fetch, false if not, a typical use of step would be:
    /// ```
    /// while try.stmt.step() {
    ///     fetch values from a query
    /// }
    /// // or
    /// let stmt = try Statement(database:db, sql:sql)
    /// try stmt.bind(param:1, "Hello")
    /// try stmt.step()
    /// try stmt.reset()
    /// try stmt.clearBindings()
    /// ```
    @discardableResult public func step() throws -> Bool {
        if !isOpen {
            isOpen = true
            db.logger?.log(sql: sql)
        }
        let rc = sqlite3_step(stmt)
        switch rc {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            assert(rc != SQLITE_OK,"Invalid return code")
            try check(rc)
        }
        fatalError("Should never get here")
    }
    
    /// Reset the statement state, so it can be re used (by calling step())
    /// Note that for some erros during `step()`, such as constaint violations, this method will throw a more specific error code.
    /// - Throws: DatabaseError
    public func reset() throws {
        try check(sqlite3_reset(stmt))
        isOpen = false
        paramIndex = 0
    }
    /// Clear bindings set using the `bind(...)` variants
    /// - Throws: DatabaseError
    public func clearBindings() throws{
        try check(sqlite3_clear_bindings(stmt))
    }
    
    /// Finalizes the statement, do not reuse it after finalizing it
    /// Automatically called when the object destructs, you only need to call this method if it is easier than making the object fall out of scope
    public func finalize(){
        guard !isFinalized else { return }
        isFinalized = true
        sqlite3_finalize(stmt)
    }
    
    @discardableResult private func check(_ rc:Int32) throws -> Self{
        try db.check(rc)
        return self
    }
    
    private func autoParamIndex(_ value:Int) -> Int {
        guard value == Statement.autoParam else {
            return value
        }
        paramIndex += 1
        return paramIndex
    }
    
    private var isOpen = false
    private var isFinalized = false
    private let sql:String
    private let stmt:OpaquePointer
    private let db:Database
    private var paramIndex = 0
    public static let autoParam = -1
}

