# SwiftSQLite

![Swift](https://github.com/moshegottlieb/SwiftSQLite/workflows/Swift/badge.svg)


SQLite wrapper for swift, nothing more, nothing less.  

## What is it?
A simple straight forward wrapper for the C API of SQLite.  
Connect to SQLite databases, run queries, prepare statements and bind parameters, just like you'd do with the regular SQLite API, just with a swift wrapper.  
If you want a light local database API without all the bells and whistles of other SQLite wrappers - this library is for you

## What it is **NOT**
- This is **not** another ORM database
- It will not try to save you from using the wrong thread when you shouldn't be doing that
- It will not guess your scheme, create it, maintain it, and automagically sync to a remote server with zero code on your part - if you like the idea of zero coding - you're in the wrong line of work

## Cook book

### Create a DB connection
```swift
// For example, place the database in the user's library folder
guard let path = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("db.sqlite").absoluteString else { fatalError("Could not create path") }
let db = try Database(path:path)
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

### Set [journal mode](https://www.sqlite.org/pragma.html#pragma_journal_mode) 

```swift
try db.set(journalMode: .wal) // Set journaling mode to WAL, useful when several processes read the datbase file, such as with an app and an app extension
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

# Install

## Swift Package Manager

Add the following to your Package.swift dependencies:

```swift
dependencies: [
...
.package(url: "https://github.com/moshegottlieb/SwiftSQLite.git", from: "1.0.1")
...
]
```
## How to add to an existing Xcode project

Select your project, in the *general* tab, under *Frameworks and Libraries*, hit the **+** button.  
Enter the URL:  
`https://github.com/moshegottlieb/SwiftSQLite.git`  
Choose your version, and you're done.
