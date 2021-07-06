//
//  Log.swift
//  
//
//  Created by Moshe Gottlieb on 06.07.21.
//

import Foundation

/// Log protocol
public protocol Log  {
    /// Log SQL
    /// - parameters:
    ///   - prepare: SQL statement being prepared
    func log(prepare:String)
    /// Log error
    /// - parameters:
    ///  - error: Error text
    ///  - code: Error code (SQLite state)
    func log(error:String,code:Int)
    /// Log statement execution
    /// - parameters:
    ///  - sql: Executed SQL
    func log(sql:String)
    /// Log a message
    /// - parameters:
    ///   - message: Message to log (open DB, etc.)
    func log(message:String)
}


/// Example console log
/// Can be used to log SQLs to the console
public struct ConsoleLog : Log {
    public init(){}
    public func log(prepare: String) {
        print("[PREPARE] \(prepare)")
    }
    ///   - params: optional parameters
    public func log(sql: String){
        print("[EXEC] \(sql)")
    }
    public func log(error:String,code:Int){
        print("[ERROR] \(error) (\(code)")
    }
    public func log(message:String){
        print("[MESSAGE] \(message)")
    }
}
