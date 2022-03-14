//
//  File.swift
//  
//
//  Created by Moshe Gottlieb on 09.03.22.
//

import Foundation
import SQLite3

/// Custom SQL function in swift, something like `SELECT my_custom_discount_function(price) FROM products`
public extension Database {
    
    /// SQLFunction type used by the `function` for scalar functions
    /// Parameter is an array of values
    /// Return one of the supported `Result` values, or nil to return a NULL value
    /// @see Value
    typealias SQLFunction = ([SQLValue]?) throws -> SQLResult?
    
    /// SQLFunction type used by the `step` function for aggregate functions
    /// Parameter are the previous result value, set to null, and an array of values
    /// Change the value of the Result (including type if needed)
    /// @see Value
    /// @see Result
    typealias SQLStepFunction = ([SQLValue]?,SQLResult) throws -> Void
    
    /// SQLFinalFunction type used by the `final` function for aggregate functions
    /// Return one of the supported `Result` values, or nil to return a NULL value
    typealias SQLFinalFunction = (SQLResult) throws -> Void?

    /// Delete a custom function
    /// Match is made by the name and number of arguments
    /// - Parameters:
    ///     - name:  The name of the function
    ///     - nArgs: Number of arguments for this function, or -1 for any number of arguments
    /// - Throws: DatabaseError
    func deleteFunction(name:String,nArgs:Int = -1) throws {
        try createFunction(name: name, nArgs: nArgs)
    }
    
    /// Create an aggregate function
    /// It is possible to create multiple overloads, based on the number of arguments
    /// Match is made by the name and number of arguments
    /// - Parameters:
    ///     - name:  The name of the function
    ///     - nArgs: Number of arguments for this function, or -1 for any number of arguments
    ///     - step: The step SQL function, called for each row
    ///     - final: The final SQL function, called when the aggregate expression is finalized
    ///     - deterministic: True if the function always returns the same value for the same input, can be used for optimization.
    ///     An example of a non determnistic function would be a function returning a random number.
    ///     See [original documentation](https://sqlite.org/c3ref/c_deterministic.html#sqlitedeterministic)  at the SQLite website
    ///     - directOnly: Set to true to disallow non direct use, such as in triggers, views, check constraints and defaults.
    ///     Read more about the **security** [implications of this flag](https://sqlite.org/c3ref/c_deterministic.html#sqlitedirectonly)  at the SQLite website
    /// - Throws: DatabaseError
    func createAggregateFunction(name:String,nArgs:Int = -1,step:@escaping SQLStepFunction,final:SQLFinalFunction?=nil,deterministic:Bool = true,directOnly:Bool = true) throws {
        try createFunction(name: name, nArgs: nArgs, step:step,final:final,deterministic: deterministic,directOnly: directOnly)
    }
    
    /// Create a scalar function
    /// It is possible to create multiple overloads, based on the number of arguments
    /// Match is made by the name and number of arguments
    /// - Parameters:
    ///     - name:  The name of the function
    ///     - nArgs: Number of arguments for this function, or -1 for any number of arguments
    ///     - function: The SQL function
    ///     - deterministic: True if the function always returns the same value for the same input, can be used for optimization.
    ///     An example of a non determnistic function would be a function returning a random number.
    ///     See [original documentation](https://sqlite.org/c3ref/c_deterministic.html#sqlitedeterministic)  at the SQLite website
    ///     - directOnly: Set to true to disallow non direct use, such as in triggers, views, check constraints and defaults.
    ///     Read more about the **security** [implications of this flag](https://sqlite.org/c3ref/c_deterministic.html#sqlitedirectonly)  at the SQLite website
    /// - Throws: DatabaseError
    func createScalarFunction(name:String,nArgs:Int = -1,function:@escaping SQLFunction,deterministic:Bool = true,directOnly:Bool = true) throws {
        try createFunction(name: name, nArgs: nArgs, function: function,deterministic: deterministic,directOnly: directOnly)
    }
    
    private func createFunction(name:String,nArgs:Int = -1,function:SQLFunction? = nil,step:SQLStepFunction? = nil,final:SQLFinalFunction? = nil,deterministic:Bool = true,directOnly:Bool = true) throws {
        let name = name.cString(using: .utf8)
        let nArgs = Int32(nArgs)
        let UPPER_VALUE = sqlite3_limit(handle,SQLITE_LIMIT_FUNCTION_ARG,-1)
        guard (-1...UPPER_VALUE) ~= nArgs else {
            throw DatabaseError(reason: "Range of parameters: -1 to \(UPPER_VALUE)", code: -1)
        }
        
        let context = Context(functionCallback: function, stepCallback: step, finalCallback: final)
        let context_ptr = Unmanaged.passRetained(context).toOpaque()
        var flags:Int32 = SQLITE_UTF8
        if deterministic {
            flags |= SQLITE_DETERMINISTIC
        }
        if directOnly {
            flags |= SQLITE_DIRECTONLY
        }
        try check(sqlite3_create_function_v2(
            handle,
            name,
            nArgs,
            flags,
            context_ptr,
            function == nil ? nil : functionCallback,
            step == nil ? nil : stepCallback,
            // Check if **step** is nil, because we have to provide a callback for final if so.
            // If the user does not supply a callback, we'll just set the pending result, which is usually what is needed anyway
            step == nil ? nil : finalCallback,
            { // Lastly, the destructor for our context object
                ptr in
                Unmanaged<Context>.fromOpaque(ptr!).release()
            }))
    }
}
    

internal class Context {
    init(functionCallback:Database.SQLFunction?,stepCallback:Database.SQLStepFunction?,finalCallback:Database.SQLFinalFunction?){
        self.functionCallback = functionCallback
        self.stepCallback = stepCallback
        self.finalCallback = finalCallback
    }
    let functionCallback:Database.SQLFunction?
    let stepCallback:Database.SQLStepFunction?
    let finalCallback:Database.SQLFinalFunction?
    
}

fileprivate func functionCallback(_ context:OpaquePointer?,_ nArgs:Int32,_ args:UnsafeMutablePointer<OpaquePointer?>?) -> Void {
        let context:OpaquePointer! = context
        let appContext = Unmanaged<Context>.fromOpaque(sqlite3_user_data(context)!).takeUnretainedValue()
        var values = [SQLValue]()
        guard let args = args else {
            sqlite3_result_error_nomem(context)
            return
        }
        for i in 0..<nArgs {
            values.append(SQLValue(args[Int(i)]))
        }
        do {
            let result = try appContext.functionCallback?(values) ?? SQLResult()
            result.apply(context: context)
        } catch let error as DatabaseError {
            sqlite3_result_error_code(context,error.code)
        } catch {
            sqlite3_result_error(context, error.localizedDescription.cString(using: .utf8), -1)
        }
}

fileprivate func stepCallback(_ context:OpaquePointer?,_ nArgs:Int32,_ args:UnsafeMutablePointer<OpaquePointer?>?) -> Void {
        let context:OpaquePointer! = context
    let appContext = Unmanaged<Context>.fromOpaque(sqlite3_user_data(context)!).takeUnretainedValue()
        var values = [SQLValue]()
        guard let args = args else {
            sqlite3_result_error_nomem(context)
            return
        }
        for i in 0..<nArgs {
            values.append(SQLValue(args[Int(i)]))
        }
        do {
            let result = SQLResult.allocate(context: context)
            try appContext.stepCallback?(values,result)
        } catch let error as DatabaseError {
            sqlite3_result_error_code(context,error.code)
        } catch {
            sqlite3_result_error(context, error.localizedDescription.cString(using: .utf8), -1)
        }
}

fileprivate func finalCallback(_ context:OpaquePointer?) -> Void {
    let appContext = Unmanaged<Context>.fromOpaque(sqlite3_user_data(context)!).takeUnretainedValue()
    do {
        let context:OpaquePointer! = context
        let result = SQLResult.final(context: context)
        try appContext.finalCallback?(result)
        result.apply(context: context)
        SQLResult.deallocate(context: context)
    } catch let error as DatabaseError {
        sqlite3_result_error_code(context,error.code)
    } catch {
        sqlite3_result_error(context, error.localizedDescription.cString(using: .utf8), -1)
    }
}
