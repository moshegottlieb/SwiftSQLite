//
//  Date+SQL.swift
//  
//
//  Created by Moshe Gottlieb on 13.08.21.
//

import Foundation

public extension Date {
    /// Initialize a date with milliseconds from midnight 1.1.1970 GMT
    ///
    /// - Parameter epoch: milliseconds from midnight 1.1.1970 GMT
    init(epoch:Int64){
        self.init(timeIntervalSince1970: TimeInterval(epoch) / 1000)
    }
    
    /// Milliseconds from midnight 1.1.1970 GMT for this date
    var epoch:Int64 {
        return Int64(timeIntervalSince1970 * 1000)
    }
}
