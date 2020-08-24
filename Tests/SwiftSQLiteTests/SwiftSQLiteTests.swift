import XCTest
@testable import SwiftSQLite

final class SwiftSQLiteTests: XCTestCase {
    

    override func setUpWithError() throws {
        db = try Database()
        try db.exec("CREATE TABLE test(a double, b int, c text, d blob)")
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
            XCTAssertEqual(mode, .off)
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

    static var allTests = [
        ("testInsert", testInsert),
        ("testInsertNull", testInsertNull),
        ("testInsertDefault", testInsertDefault),
        ("testInvalidSql", testInvalidSql),
        ("testSelect", testSelect),
        ("testNamesTypes", testNamesTypes),
        ("testLastRowId", testLastRowId),
        ("testJournalMode", testJournalMode),
        ("testForeignKeys", testForeignKeys)
    ]
    
    private var db:Database!
}
