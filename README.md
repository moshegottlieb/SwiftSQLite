# SwiftSQLite

![Swift](https://github.com/moshegottlieb/SwiftSQLite/workflows/Swift/badge.svg)
![License](https://img.shields.io/badge/License-MIT-informational?style=flat)
![Apple Platforms](https://img.shields.io/badge/Apple-000000?logo=apple&logoColor=F0F0F0)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![SQLite](https://img.shields.io/badge/SQLite-%3E%3D3.19.0-informational?style=flat&logo=SQLite)
![SQLCipher](https://img.shields.io/badge/SQLCipher-%20v4.6.1-informational?style=flat)


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

Aggregate functions are a bit more complex, but not too much.  
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

# SQLCipher

## Support 

SQLCipher is supported from version 1.1.0 and higher  

## SwiftSQLCipher or SwiftSQLite? 

To use SQLCipher instead of SQLite, please refer to `LICENSE.sqlcipher.md` license file.  
If you do not wish to use it, you can still use the standard package `SwiftSQLite`.  
If you do not plan on using encryption, I suggest you use `SwiftSQLite` as it will slightly decrease your binary size.    

## How to use SwiftSQLCipher

The follwoing methods are available for SQLCipher only:  
Instead of importing `SwiftSQLite`, import `SwiftSQLCipher`.  
After opening a database, call `setKey(:)`  

```swift
try db.setKey("TopSecretPassword")
```

This will encrypt the database if it's not already encrypted, and allow reading it if it's encrypted.  
This must be the first action on your newly created / opened database.  
You cannot use this method to encrypt already existing data.    

You can also change the database password by calling `reKey(:)`.  
The database must be opened, encrypted, and the `setKey(:)` method must have been already called.  

```swift
try db.setKey("TopSecretPassword") // must call setKey(:) BEFORE calling reKey
try db.reKey("EvenMoreSecretPassword") // will replace the password to a new key
try db.reKey(nil) // remove encryption altogether, can now read without SQLCipher
try db.removeKey() // same as reKey(nil) 
```

## Advanced SQLCipher support

```swift

// var cipherSalt:Data? { get throws }
let salt:Data? = try db.cipherSalt // database salt (16 bytes), nil if not encrypted or plain text header
...
// func setCipherSalt(_ salt:Data) throws
let salt:Data = ....
try db.setCipherSalt(salt) // set the salt for the database. you need this when using plain text header
...
// func setPlainTextHeader(size:Int32) throws
// Set a plain text header for the DB.
// This causes sqlcipher not to be able to read the salt part of your database, make sure you store it if you use it
try db.setPlainTextHeader(size:32) // 32 is recommended for iOS WAL journaling in a shared container in iOS

// func flushHeader() throws
// This simply reads the user version and writes it, you should call this after creating databases with plain text headers
try db.flushHeader()

```

## iOS mode with WAL mode and shared containers

According to SQLCipher, iOS will check if your database file is an SQLite database in WAL mode, and if so, will allow it to lock the file in the background.  
Otherwise, your app will be killed when attempting it from the background.  
Since SQLCipher databases are encrypted, iOS cannot verify the files meet the requirement.  
Read about it in the [SQLCipher documentation](https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_plaintext_header_size).    
See more in [Apple's documentation](https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_plaintext_header_size).  
The correct sequence you should use is as follows:  
```swift

    // new database
    let db = try Database(path: filename)
    try db.setKey(password)
    // SAVE this salt somewhere safe
    guard let salt = try db.cipherSalt else {
        throw E.error("Could not get salt")
    }
    try db.setPlainTextHeader(size: 32)
    try db.set(journalMode: .wal)
    try db.flushHeader()
    
    // Open an existing database
    try db.open(path: filename)
    try db.setKey(password)
    try db.setPlainTextHeader(size: 32)
    try db.setCipherSalt(salt)
    try db.set(journalMode: .wal)
    // Good to go
```

There's also a keychain supported version (Apple platforms only) which saves you the trouble.  

```swift

    // func openSharedWalDatabase(path:String,accessGroup:String? = nil,identifier:String) throws
    
    let db = try Database()
    // Use a different identifier for each database!
    try db.openSharedWalDatabase(path:"path/to/file.db",accessGroup:"com.your.shared.identifier",identifier:"MyDB")
    // Your database is now opened, encrypted, in WAL mode, and the key and salt are stored in the keychain
    // (even though the salt is not really a secret)
    
    // func deleteCredentials(accessGroup:String? = nil,identifier:String) throws
    // This will REMOVE the credentials from the keychain
    // Important: you cannot access your database after calling this method
    // Use it when deleting your database file
    try db.deleteCredentials(accessGroup:"com.your.shared.identifier",identifier:"MyDB")

```

## Keychain support (Apple platforms only)

A keychain helper is included to save the password in the keychain.  

```swift
    
    // Save key to keychain
    // Pass nil to delete the key from the keychain
    try db.saveToKeyChain(account:"mydb",key:"MySecretPassword")
    // When sharing the database using a group identifier:
    try db.saveToKeyChain(account:"mydb",key:"MySecretPassword",accessGroup:"your.group.identifier.if.you.have.it")
    
    // Delete the key from the keychain
    
    try db.deleteFromKeyChain(account:"mydb")
    try db.deleteFromKeyChain(account:"mydb",accessGroup:"your.group.identifier.if.you.have.it")
    
    // Read the password from the keychain
    if let password = try db.readFromKeyChain(account:"mydb") {
        try db.setKey(password)
    }
    // of course, readFromKeyChain accepts also an accessGroup:
    if let password = try db.readFromKeyChain(account:"mydb", accessGroup:"your.group.identifier.if.you.have.it") {
        try db.setKey(password)
    }
```

# Install

## Swift Package Manager

Add the following to your Package.swift dependencies:

```swift
dependencies: [
...
.package(url: "https://github.com/moshegottlieb/SwiftSQLite.git", from: "1.1.0")
...
]

import SwiftSQLite // for standard SQLite
import SwiftSQLCipher // for SQLCipher version

```
## How to add to an existing Xcode project

Select your project, in the *general* tab, under *Frameworks and Libraries*, hit the **+** button.  
Enter the URL:  
`https://github.com/moshegottlieb/SwiftSQLite.git`  
Choose your version, and you're done.

## Linux dependencies

The swift package manager does not automatically install the required dependencies.  
On ubuntu/debian flavors:  
`sudo apt-get install libsqlite3-dev`  
For SQLCipher:  
`sudo apt-get install sqlciper-dev`    
  
On RedHat/Centos flavors:  
`sudo yum install sqlite-devel`  
For SQLCipher:  
`sudo yum install sqlciper-devel`    
