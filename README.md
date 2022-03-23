# SwiftSQLite

![Swift](https://github.com/moshegottlieb/SwiftSQLite/workflows/Swift/badge.svg)
![Swift-Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmoshegottlieb%2FSwiftSQLite%2Fbadge%3Ftype%3Dswift-versions)
![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmoshegottlieb%2FSwiftSQLite%2Fbadge%3Ftype%3Dplatforms)


SQLite wrapper for swift, nothing more, nothing less.  

## What is it?
A simple straight forward wrapper for the C API of SQLite.  
Connect to SQLite databases, run queries, prepare statements and bind parameters, just like you'd do with the regular SQLite API, but in swift.  
If you need a light local database API without all the bells and whistles - this library is for you.  

## What it is **NOT**
- This is **not** another ORM database
- It will not guess your scheme, create it, maintain it, and automagically sync to a remote server with zero code on your part - if you like the idea of zero coding - you're in the wrong line of work

## Cook book

### Create a DB connection
```swift
// For example, place the database in the user's library folder
guard let path = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("db.sqlite").absoluteString else { fatalError("Could not create path") }
let db = try Database(path:path)
```
### Open or close a DB connection explicitly
Sometimes you'd want to close or open a databasse explicitly, and not just using the CTOR and DTOR.  
```swift
db.close() // will silently do nothing if already closed
try db.open(pathToFile) // Open a new connection, the old handle is closed first
```

### Run a simple SQL statement
```swift
try db.exec("CREATE TABLE demo(a INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, b INTEGER NOT NULL)")
```
### Prepare a statement and run with parameters
```swift
// Prepare once
let insert = try db.statement(sql: "INSERT INTO demo (b) VALUES (?)")
for i in 0..<10 {
    // Parameters are 1 based, this is how SQLite works
    try insert.bind(param: 1,i)
    try insert.step() // Run the statement
    let last_row_id = db.lastInsertRowId
    print("Last row id is: \(last_row_id)")
    try insert.reset() // must reset before we can run it again
    try insert.clearBindings() // Bindings are not cleared automatically, since we bind the same param again, this is not strictly required in this example, but it's good practice to clear the bindings.
}
```
### Run SELECT queries
```swift
let select = try db.statement(sql: "SELECT a,b FROM demo WHERE b > ?")
try select.bind(param: 1, 5)
while try select.step() {
    guard let a = select.integer(column: 0), let b = select.string(column: 1) else {
        fatalError("Expected b to be non nil")
    }
    print("a: \(a), b: \(b)")
}
```

## Additional helpers and wrappers

### Use codables

```swift

struct Student : Codable {
    let name:String
    let grade:Int
    let city:String
}

db.useJSON1 = true
try db.exec("CREATE TABLE students (value json)") // JSON1 extension, JSON is actually TEXT
let ins = try db.statement(sql: "INSERT INTO students (value) VALUES (?)")
let student = Student(name:"Bart Simpson",grade:4,city:"Springfield")
try ins.bind(param: 1,student) // Bind a decodable object
try ins.step() // Execute the statement
let sel = try db.statement(sql: "SELECT json_extract(value,"$.name") FROM students")
guard try sel.step() else { fatalError("Expected step to succeed") }
guard let the_student:Student? = sel.object(column: 0) // deduce that the object is C by the return type, which must be an optional Decodable
else { fatalError("Expected object to be decoded to a C instance") }

```

### Set [journal mode](https://www.sqlite.org/pragma.html#pragma_journal_mode) 

```swift
try db.set(journalMode: .wal) // Set journaling mode to WAL, useful when several processes read the database file, such as with an app and an app extension
let current_mode = try db.journalMode()
```
### [Auto vacuum](https://sqlite.org/pragma.html#pragma_auto_vacuum)
```swift
let db.set(autoVacuum:.incremental)
// do some inserts, deletes here
try db.incrementalVacuum()
```

### [Vacuum](https://sqlite.org/lang_vacuum.html)
```swift
try db.vacuum()
```

### [Foreign keys on/off](https://sqlite.org/pragma.html#pragma_foreign_keys)
```swift
db.foreignKeys = true
// foreign keys are now enforced
try db.withoutForeignKeys {
    // This code will run without foreign keys enforcement 
}
try db.withForeignKeys {
    // This code will run with foreign keys enforcement
}
```

### [Recursive triggers on/off](https://www.sqlite.org/pragma.html#pragma_recursive_triggers)
Recursive triggers are off by default, but according to the docs, _may be turned on by default in future versions_.  
An example of a self limiting recursive trigger:
```sql
CREATE TABLE rt(a INTEGER);
CREATE TRIGGER rt_trigger AFTER INSERT ON rt WHEN new.a < 10
BEGIN
    INSERT INTO rt VALUES (new.a + 1);
END;
```

```swift
db.recursiveTriggers = true
try db.exec("INSERT INTO rt VALUES (1)")
// rt should now have the 10 values (1..10)
// if recursiveTriggers was off - rt would only have 2 rows (1,2) as the trigger would not trigger itself.
```



### Set busy timeout
```swift
try db.set(busyTimoeut:30)
```
This will install a busy handler that will sleep until the database unlocks or until the timeout expires, useful for WAL mode.  
See [busy handler](http://sqlite.org/c3ref/busy_handler.html) and [PRAGMA busy_timouet](https://sqlite.org/pragma.html#pragma_busy_timeout).      
Note that there can be only a single busy handler for a database connection.  

### Versions

Set the user version or get the user, data or schema versions.   
See [PRAGMA data_version](https://sqlite.org/pragma.html#pragma_data_version)  
See [PRAGMA schema_version](https://sqlite.org/pragma.html#pragma_schema_version)  
See [PRAGMA user_version](https://sqlite.org/pragma.html#pragma_user_version)

```swift
let user_version = try db.get(version: .user) // 0 by default
let schema_version = try db.get(version: .schema) 
let data_version = try db.get(version: .data) 
try db.set(version:12)

```

### Custom functions

SQLite lets you create user defined functions, and SwiftSQLite lets you do that in swift 🤓.  
We'll be using the `Value` and `Result` classes here.  
A `Value` is an argument provided to your functions, and a `Result`, is a result from your functions.  
  
Here's an example of a scalar function: 
```swift
try db.createScalarFunction(name: "custom_sum_all_args", nArgs: 1, function: { (values:[Value]?) in
    var sum = 0
        values?.forEach({ value in
            sum += value.intValue
        })
    return Result(sum)
})
```

Now you can call:

```sql
SELECT custom_sum_all_args(1,2,3)
```
The returned value would be 6! (1+2+3).  

Aggregate functions are a bit more complex, but not to much.  
Here's a similar example, but as an aggregate function:
  
```swift
try db.createAggregateFunction(name: "custom_agg_test", step: { (values:[Value]?,result:Result) in
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
```

You can now use it as an aggrageted function:  
```sql
SELECT custom_agg_test(value,1) FROM json_each(json_array(1,2,3))
``` 
The resulting value should be 9. ( (1 + 1) + (2 + 1) + (3 + 1) )

### Logging

It is possible to install a logger by implementing the protocol `Log`:
```swift
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
```
Set the static property `logger` for the `Database` class and you're ready to go.  
A built in console logger is available, to use it, just add:  
`Database.logger = ConsoleLog()`   
Better set it up before using the library (but can be set in any point).

# Install

## Swift Package Manager

Add the following to your Package.swift dependencies:

```swift
dependencies: [
...
.package(url: "https://github.com/moshegottlieb/SwiftSQLite.git", from: "1.0.40")
...
]
```
## How to add to an existing Xcode project

Select your project, in the *general* tab, under *Frameworks and Libraries*, hit the **+** button.  
Enter the URL:  
`https://github.com/moshegottlieb/SwiftSQLite.git`  
Choose your version, and you're done.
