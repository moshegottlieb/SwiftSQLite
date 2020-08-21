# SwiftSQLite

SQLite wrapper for swift, nothing more, nothing less.  

## What it is 
A simple straight forward wrapper for the C API of SQLite.  
Connect to SQLite databases, run queries, prepare statements and bind parameters, just like you'd do with the regular SQLite API, just with a swift wrapper.  
If you want a light local database API without all the bells and whistles of other SQLite wrappers - this library is for you

## What it is **NOT**
- This is **not** another ORM database
- it will not try to save you from using the wrong thread when you shouldn't be doing that
- It will not guess your scheme, create it, maintain it, and automagically sync to a remote server with zero code on your part - if you like the idea of zero coding - you're in the wrong line of work

## Cook book

## Create a DB connection
```swift
// For example, place the database in the user's library folder
guard let path = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("db.sqlite").absoluteString else { fatalError("Could not create path")
let db = try Database(path:path)
```

## Run a simple SQL statement
```swift
try db.exec("CREATE TABLE demo(a INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, b INTEGER NOT NULL)")
```
## Prepare a statement and run with parameters
```swift
// Prepare once
let insert = try Statement(database: db, sql: "INSERT INTO demo (b) VALUES (?)")
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
## Run SELECT queries
```swift
let select = try Statement(database: db, sql: "SELECT a,b FROM demo WHERE b > ?")
try select.bind(param: 1, 5)
while try select.step() {
    guard let a = select.integer(column: 0), let b = select.string(column: 1) else {
        fatalError("Expected b to be non nil")
    }
    print("a: \(a), b: \(b)")
}
```

### Install

## Swift Package Manager

Add the following to your Package.swift dependencies:

```swift
dependencies: [
...
.package(url: "https://github.com/moshegottlieb/SwiftSQLite.git", from: "1.0.1")
...
]
```
## To an existing Xcode project

Select your project, in the *general* tab, under *Frameworks and Libraries*, hit the **+** button.  
Enter the URL:  
`https://github.com/moshegottlieb/SwiftSQLite.git`  
Choose your version, and you're done.
