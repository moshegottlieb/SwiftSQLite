import XCTest

#if SWIFT_SQLITE_CIPHER
@testable import SwiftSQLCipher
#else
@testable import SwiftSQLite
#endif



fileprivate let dbPath = FileManager.default.temporaryDirectory.path.appending("/test.sqlite")

final class SwiftSQLiteTests: XCTestCase {
    
    override func setUpWithError() throws {
        try? FileManager.default.removeItem(atPath: dbPath)
        db = try Database(path:dbPath)
        #if SWIFT_SQLITE_CIPHER
        try db.setKey("TopSecret")
        #endif
        try db.exec("CREATE TABLE test(a double, b int, c text, d blob)")
    }
    
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(atPath: dbPath)
    }
    
    
    
    func testInsert(){
        let t = {
            let stmt = try self.db.statement(sql:"INSERT INTO test(a,b,c,d) VALUES (?,?,?,?)")
            try stmt.bind(param: 1, 123.2)
            try stmt.bind(param: 2, 123)
            try stmt.bind(param: 3, "123")
            try stmt.bind(param: 4, Data(count: 20))
            try stmt.step()
        }
        XCTAssertNoThrow(try t())
    }
    
    func testAutoParam(){
        let t = {
            let stmt = try self.db.statement(sql: "SELECT ?,?,?")
            XCTAssertTrue(try stmt.bind(1).bind(2).bind(3).step())
            XCTAssertEqual(stmt.integer(column: 0), 1)
            XCTAssertEqual(stmt.integer(column: 1), 2)
            XCTAssertEqual(stmt.integer(column: 2), 3)
        }
        XCTAssertNoThrow(try t())
    }
    
    
    func testInsertNull(){
        let t = {
            let stmt = try self.db.statement(sql:"INSERT INTO test(a,b,c,d) VALUES (?,?,?,?)")
            try stmt.bind(param: 1)
            try stmt.bind(param: 2)
            try stmt.bind(param: 3)
            try stmt.bind(param: 4)
            try stmt.step()
        }
        XCTAssertNoThrow(try t())
    }
    
    func testInsertDefault(){
        let t = {
            let stmt = try self.db.statement(sql:"INSERT INTO test(a,b,c,d) VALUES (?,?,?,?)")
            try stmt.step()
        }
        XCTAssertNoThrow(try t())
    }
    func testInvalidSql(){
        let t = {
            let stmt = try self.db.statement(sql:"Always look on the bright side of life")
            try stmt.step()
        }
        XCTAssertThrowsError(try t())
    }
    
    func testSelect(){
        let t = {
            let stmt = try self.db.statement(sql:"INSERT INTO test(a,b,c,d) VALUES (?,?,?,?)")
            for i in 0..<10 {
                try stmt.bind(param: 1, Double(i)/2)
                try stmt.bind(param: 2, i)
                try stmt.bind(param: 3, "\(i)")
                try stmt.bind(param: 4, "\(i)".data(using: .utf8)!)
                try stmt.step()
                try stmt.reset()
            }
            let select = try self.db.statement(sql:"SELECT * FROM test ORDER BY ROWID")
            var count = 0
            while (try select.step()){
                let dbl = select.double(column: 0)
                XCTAssertNotNil(dbl)
                XCTAssertEqual(dbl,Double(count) / 2)
                let int = select.integer(column: 1)
                XCTAssertNotNil(int)
                XCTAssertEqual(int,count)
                // Read the integer column as a string
                let str_int = select.string(column: 1)
                XCTAssertNotNil(str_int)
                XCTAssertEqual("\(count)",str_int)
                let str = select.string(column: 2)
                XCTAssertNotNil(str)
                XCTAssertEqual(str,"\(count)")
                let dat = select.data(column: 3)
                XCTAssertNotNil(dat)
                XCTAssertEqual(dat!.base64EncodedString(),str!.data(using: .utf8)!.base64EncodedString())
                count += 1
            }
            XCTAssertEqual(count,10, "Expected 10 rows")
        }
        XCTAssertNoThrow(try t())
    }
    
    func testNamesTypes(){
        
        let t = {
            let stmt_i = try self.db.statement(sql:"SELECT 1")
            XCTAssert(try stmt_i.step())
            XCTAssertEqual(stmt_i.columns(),1)
            XCTAssertEqual(stmt_i.type(column: 0),.integer)
            XCTAssertEqual(stmt_i.name(column: 0),"1")
            XCTAssertEqual(stmt_i.integer(column: 0),1)
            let stmt_d = try self.db.statement(sql:"SELECT 1.1")
            XCTAssert(try stmt_d.step())
            XCTAssertEqual(stmt_d.columns(),1)
            XCTAssertEqual(stmt_d.type(column: 0),.double)
            XCTAssertEqual(stmt_d.name(column: 0),"1.1")
            XCTAssertEqual(stmt_d.double(column: 0),1.1)
            let stmt_s = try self.db.statement(sql:"SELECT 'A'")
            XCTAssert(try stmt_s.step())
            XCTAssertEqual(stmt_s.columns(),1)
            XCTAssertEqual(stmt_s.type(column: 0),.string)
            XCTAssertNil(stmt_s.originName(column: 0), "Original name should be nil, as there is no table")
            XCTAssertNil(stmt_s.tableName(column: 0), "Table name should be nil, as there is no table")
            XCTAssertEqual(stmt_s.name(column: 0),"'A'")
            XCTAssertEqual(stmt_s.string(column: 0),"A")
            let stmt_b = try self.db.statement(sql:"SELECT x'0500'")
            XCTAssert(try stmt_b.step())
            XCTAssertEqual(stmt_b.columns(),1)
            XCTAssertEqual(stmt_b.type(column: 0),.data)
            let stmt_n = try self.db.statement(sql:"SELECT NULL")
            XCTAssert(try stmt_n.step())
            XCTAssertEqual(stmt_n.columns(),1)
            XCTAssertEqual(stmt_n.type(column: 0),.null)
            XCTAssert(stmt_n.isNull(column: 0))
            try self.db.exec("CREATE TABLE test1 (a INT)")
            let stmt_t = try self.db.statement(sql:"SELECT test.a at,test1.a at1 FROM test,test1")
            XCTAssertEqual(stmt_t.name(column: 0),"at")
            XCTAssertEqual(stmt_t.name(column: 1),"at1")
            XCTAssertEqual(stmt_t.tableName(column: 0),"test")
            XCTAssertEqual(stmt_t.tableName(column: 1),"test1")
            XCTAssertEqual(stmt_t.originName(column: 0),"a")
            XCTAssertEqual(stmt_t.originName(column: 1),"a")
        }
        XCTAssertNoThrow(try t())
    }
    
    func testLastRowId(){
        let t = {
            try self.db.exec("CREATE TABLE auto_inc(id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT)")
            let stmt = try self.db.statement(sql: "INSERT INTO auto_inc (value) VALUES ('Some text')")
            try stmt.step()
            let last_row_id = self.db.lastInsertRowId
            XCTAssert(last_row_id > 0)
        }
        XCTAssertNoThrow(try t())
    }
    
    func testJournalMode(){
        let t = {
            try self.db.set(journalMode: .off) // OK to set off for memory databases
            let mode = try self.db.journalMode()
            XCTAssertTrue(mode == .off || mode == .memory)
        }
        XCTAssertNoThrow(try t())
    }
    
    func testRecursiveTriggers(){
        let t = {
            try self.db.exec("""
CREATE TABLE rt(a INTEGER);
CREATE TRIGGER rt_trigger AFTER INSERT ON rt WHEN new.a < 10
BEGIN
    INSERT INTO rt VALUES (new.a + 1);
END;
""")
            self.db.recursiveTriggers = false
            try self.db.exec("INSERT INTO rt VALUES (1)")
            let count = try self.db.statement(sql: "SELECT COUNT(*) FROM rt")
            try XCTAssertTrue(count.step())
            var value = count.integer(column: 0)
            XCTAssertEqual(value,2) // One + one time trigger (not recursive)
            try count.reset()
            self.db.recursiveTriggers = true
            try self.db.exec("INSERT INTO rt VALUES (1)")
            try XCTAssertTrue(count.step())
            value = count.integer(column: 0)
            XCTAssertEqual(value,12) // 2 from before + 10 times recursive trigger call
        }
        XCTAssertNoThrow(try t())
    }
    
    func testForeignKeys(){
        let t = {
            try self.db.exec("CREATE TABLE F1(a INTEGER PRIMARY KEY NOT NULL)")
            try self.db.exec("CREATE TABLE F2(a INTEGER PRIMARY KEY NOT NULL REFERENCES F1(a) ON DELETE CASCADE)")
            try self.db.exec("INSERT INTO F1 VALUES (1)")
            try self.db.withForeignKeys {
                XCTAssert(self.db.foreignKeys)
                try self.db.exec("INSERT INTO F2 VALUES (1)")
                XCTAssertThrowsError(try self.db.exec("INSERT INTO F2 VALUES (2)"))
                try self.db.exec("DELETE FROM F1")
                let cnt_stmt = try self.db.statement(sql: "SELECT COUNT(*) FROM F2")
                XCTAssert(try cnt_stmt.step())
                let cnt = cnt_stmt.integer(column: 0)
                XCTAssertNotNil(cnt)
                XCTAssertEqual(cnt, 0)
            }
            try self.db.withoutForeignKeys {
                self.db.foreignKeys = false
                try self.db.exec("INSERT INTO F2 VALUES (3)")
                try self.db.exec("DROP TABLE F2")
                try self.db.exec("DROP TABLE F1")
            }
        }
        XCTAssertNoThrow(try t())
    }
    
    func testMultiple(){
        let t = {
            try self.db.exec("CREATE TABLE M1(a INTEGER PRIMARY KEY NOT NULL); INSERT INTO M1 (a) VALUES (1); DELETE FROM M1; INSERT INTO M1 (a) VALUES (1);")
            let stmt = try self.db.statement(sql: "SELECT a FROM M1")
            XCTAssert(try stmt.step())
            XCTAssertEqual(stmt.integer(column: 0), 1)
        }
        XCTAssertNoThrow(try t())
    }

    func testVersion(){
        let t = {
            let v = try self.db.get(version: .user)
            XCTAssert(v == 0)
            try self.db.set(version: 1)
            XCTAssert(try self.db.get(version: .user) == 1)
        }
        XCTAssertNoThrow(try t())
    }
    
    func testFunction() {
        
        let test_scalar = {
            try self.db.createScalarFunction(name: "custom_to_string", nArgs: 1, function: { (values:[SQLValue]?) in
                guard let values = values, values.count == 1 else {
                    throw DatabaseError(reason: "Expected exactly 1 parameter", code: -1)
                }
                let value = values[0].intValue
                return SQLResult("\(value)")
            })
            let stmt = try self.db.statement(sql: "SELECT custom_to_string(10)")
            XCTAssertTrue(try stmt.step())
            XCTAssertTrue(stmt.string(column: 0) == "10")
            stmt.finalize()
            try self.db.deleteFunction(name: "custom_to_string", nArgs: 1)
        }
        
        let test_aggregate = {
            try self.db.createAggregateFunction(name: "custom_agg_test", step: { (values:[SQLValue]?,result:SQLResult) in
                // Sum all arguments
                var sum = 0
                values?.forEach({ v in
                    sum += v.intValue
                })
                // Is it the first value we're setting?
                if result.resultType == .Null {
                    // Set the initial value, result type will be automatically set to Int
                    result.intValue = sum
                } else {
                    // Nope, not the first time, sum with previous value
                    result.intValue! += sum
                }
            })
            
            try self.db.exec("CREATE TABLE vals (value INTEGER)")
            
            try self.db.exec("INSERT INTO vals VALUES (1),(2),(3)")
            
            let stmt = try self.db.statement(sql: "SELECT custom_agg_test(value,1) FROM vals")
            XCTAssertTrue(try stmt.step())
            let value = stmt.integer(column: 0)
            // Should be:
            // (1 + 1) + (2 + 1) + (3 + 1) = 9
            XCTAssertEqual(value, 9)
            stmt.finalize()
            try self.db.deleteFunction(name: "custom_agg_test")
        }
        
        let test_direct = { (direct:Bool) in
            let fn_name = "custom_to_string"
            let scalar:Database.SQLFunction = { (values:[SQLValue]?) in
                guard let values = values, values.count == 1 else {
                    throw DatabaseError(reason: "Expected exactly 1 parameter", code: -1)
                }
                let value = values[0].intValue
                return SQLResult("\(value)")
            }
            try self.db.createScalarFunction(name: fn_name, nArgs: 1, function: scalar, deterministic: true, directOnly: direct)
            try self.db.exec("CREATE TABLE numbers(n INT)")
            
            try self.db.exec("CREATE TABLE log(line TEXT)")
            try self.db.exec("""
CREATE TRIGGER test_trigger AFTER DELETE ON numbers
FOR EACH ROW
BEGIN
    INSERT INTO log (line) VALUES (custom_to_string(old.n));
END;
""")
            try self.db.exec("INSERT INTO numbers (n) VALUES (1)")
            // Will throw an error if the direct only flag is true, meaning the custom function should not be available for non direct statements (such as triggers)
            try self.db.exec("DELETE FROM numbers")
            let stmt = try self.db.statement(sql: "SELECT line FROM log")
            XCTAssertTrue(try stmt.step())
            let value = stmt.string(column: 0)
            stmt.finalize()
            XCTAssertEqual(value, "1")
            try self.db.exec("DROP TRIGGER test_trigger")
            try self.db.exec("DROP TABLE log")
            try self.db.exec("DROP TABLE numbers")
            try self.db.deleteFunction(name: fn_name, nArgs: 1)
        }
        
        XCTAssertNoThrow(try test_scalar())
        XCTAssertNoThrow(try test_aggregate())
        XCTAssertNoThrow(try test_direct(false))
    #if os(Linux)
        // Don't test direct on linux, not supported
    #else
        XCTAssertThrowsError(try test_direct(true))
    #endif
        
    }
    
    func testCodable() {
        let t = {
            struct C : Codable {
                let a:Int
            }
            self.db.useJSON1 = false
            try self.db.exec("CREATE TABLE json_t(a JSON NOT NULL)")
            var ins = try self.db.statement(sql: "INSERT INTO json_t (a) VALUES (?)")
            try ins.bind(param: 1,C(a: 0))
            try ins.step()
            var sel = try self.db.statement(sql: "SELECT a FROM json_t LIMIT 1")
            XCTAssert(try sel.step())
            var o:C? = sel.object(column: 0)
            try sel.reset()
            XCTAssertNotNil(o)
            try self.db.exec("DROP TABLE json_t")
            
            self.db.useJSON1 = true
            try self.db.exec("CREATE TABLE json_t(a JSON NOT NULL)")
            ins = try self.db.statement(sql: "INSERT INTO json_t (a) VALUES (?)")
            try ins.bind(param: 1,C(a: 0))
            try ins.step()
            sel = try self.db.statement(sql: "SELECT a FROM json_t LIMIT 1")
            XCTAssert(try sel.step())
            o = sel.object(column: 0)
            try sel.reset()
            XCTAssertNotNil(o)
            try self.db.exec("DROP TABLE json_t")
        }
        XCTAssertNoThrow(try t())
    }
    
    static var allTests = [
        ("testInsert", testInsert),
        ("testInsertNull", testInsertNull),
        ("testInsertDefault", testInsertDefault),
        ("testInvalidSql", testInvalidSql),
        ("testSelect", testSelect),
        ("testNamesTypes", testNamesTypes),
        ("testLastRowId", testLastRowId),
        ("testJournalMode", testJournalMode),
        ("testForeignKeys", testForeignKeys),
        ("testRecursiveTriggers", testRecursiveTriggers),
        ("testMultiple", testMultiple),
        ("testVersion", testVersion),
        ("testCodable", testCodable),
        ("testFunction", testFunction),
        ("testAutoParam", testAutoParam)
    ]
    
    private var db:Database!
}
