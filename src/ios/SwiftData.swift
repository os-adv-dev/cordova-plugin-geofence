//
// SwiftData.swift
//
// Copyright (c) 2014 Ryan Fowler
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import UIKit


// MARK: - SwiftData

public struct SwiftData {


    // MARK: - Public SwiftData Functions


    // MARK: - Execute Statements

    /**
    Execute a non-query SQL statement (e.g. INSERT, UPDATE, DELETE, etc.)

    This function will execute the provided SQL and return an Int with the error code, or nil if there was no error.
    It is recommended to always verify that the return value is nil to ensure that the operation was successful.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter sqlStr:  The non-query string of SQL to be executed (INSERT, UPDATE, DELETE, etc.)

    - returns:       An Int with the error code, or nil if there was no error
    */
    public static func executeChange(_ sqlStr: String) -> Int? {

        //create error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the change statement
            error = SQLiteDB.sharedInstance.executeChange(sqlStr)

            //close database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Execute a non-query SQL statement (e.g. INSERT, UPDATE, DELETE, etc.) along with arguments to be bound to the characters "?" (for values) and "i?" (for identifiers e.g. table or column names).

    The objects in the provided array of arguments will be bound, in order, to the "i?" and "?" characters in the SQL string.
    The quantity of "i?"s and "?"s in the SQL string must be equal to the quantity of arguments provided.
    Objects that are to bind as an identifier ("i?") must be of type String.
    Identifiers should be bound and escaped if provided by the user.
    If "nil" is provided as an argument, the NULL value will be bound to the appropriate value in the SQL string.
    For more information on how the objects will be escaped, refer to the functions "escapeValue()" and "escapeIdentifier()".
    Note that the "escapeValue()" and "escapeIdentifier()" include the necessary quotations ' ' or " " to the arguments when being bound to the SQL.

    It is recommended to always verify that the return value is nil to ensure that the operation was successful.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - binding errors (201 - 203)

    - parameter sqlStr:    The non-query string of SQL to be executed (INSERT, UPDATE, DELETE, etc.)
    - parameter withArgs:  An array of objects to bind to the "?" and "i?" characters in the sqlStr

    - returns:         An Int with the error code, or nil if there was no error
    */
    public static func executeChange(_ sqlStr: String, withArgs: [AnyObject]) -> Int? {

        //create success variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the change statement
            error = SQLiteDB.sharedInstance.executeChange(sqlStr, withArgs: withArgs)

            //close database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Execute multiple SQL statements (non-queries e.g. INSERT, UPDATE, DELETE, etc.)

    This function will execute each SQL statment in the provided array, in order, and return an Int with the error code, or nil if there was no error.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter sqlArr:  An array of non-query strings of SQL to be executed (INSERT, UPDATE, DELETE, etc.)

    - returns:       An Int with the error code, or nil if there was no error
    */
    public static func executeMultipleChanges(_ sqlArr: [String]) -> Int? {

        //create error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the change statements
            for sqlStr in sqlArr {
                if let err = SQLiteDB.sharedInstance.executeChange(sqlStr) {
                    SQLiteDB.sharedInstance.close()
                    if let index = sqlArr.index(of: sqlStr) {
                        print("Error occurred on array item: \(index) -> \"\(sqlStr)\"")
                    }
                    error = err
                    return
                }
            }

            //close database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Execute a SQLite query statement (e.g. SELECT)

    This function will execute the provided SQL and return a tuple of:
    - an Array of SDRow objects
    - an Int with the error code, or nil if there was no error

    The value for each column in an SDRow can be obtained using the column name in the subscript format similar to a Dictionary, along with the function to obtain the value in the appropriate type (.asString(), .asDate(), .asData(), .asInt(), .asDouble(), and .asBool()).
    Without the function call to return a specific type, the SDRow will return an object with type AnyObject.
    Note: NULL values in the SQLite database will be returned as 'nil'.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter sqlStr:  The query String of SQL to be executed (e.g. SELECT)

    - returns:       A tuple containing an Array of "SDRow"s, and an Int with the error code or nil if there was no error
    */
    public static func executeQuery(_ sqlStr: String) -> (result: [SDRow], error: Int?) {

        //create result and error variables
        var result = [SDRow] ()
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the query statement
            (result, error) = SQLiteDB.sharedInstance.executeQuery(sqlStr)

            //close database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }

    /**
    Execute a SQL query statement (e.g. SELECT) with arguments to be bound to the characters "?" (for values) and "i?" (for identifiers e.g. table or column names).

    See the "executeChange(sqlStr: String, withArgs: [AnyObject?])" function for more information on the arguments provided and binding.

    See the "executeQuery(sqlStr: String)"  function for more information on the return value.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - binding errors (201 - 203)

    - parameter sqlStr:    The query String of SQL to be executed (e.g. SELECT)
    - parameter withArgs:  An array of objects that will be bound, in order, to the characters "?" (for values) and "i?" (for identifiers, e.g. table or column names) in the sqlStr.

    - returns:       A tuple containing an Array of "SDRow"s, and an Int with the error code or nil if there was no error
    */
    public static func executeQuery(_ sqlStr: String, withArgs: [AnyObject]) -> (result: [SDRow], error: Int?) {

        //create result and error variables
        var result = [SDRow] ()
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the query statement
            (result, error) = SQLiteDB.sharedInstance.executeQuery(sqlStr, withArgs: withArgs)

            //close database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }

    /**
    Execute functions in a closure on a single custom connection


    Note: This function cannot be nested within itself, or inside a transaction/savepoint.

    Possible errors returned by this function are:

    - custom connection errors (301 - 306)

    - parameter flags:    The custom flag associated with the connection. Can be either:
                        - .ReadOnly
                        - .ReadWrite
                        - .ReadWriteCreate

    - parameter closure:  A closure containing functions that will be executed on the custom connection

    - returns:        An Int with the error code, or nil if there was no error
    */
    public static func executeWithConnection(_ flags: SD.Flags, closure: @escaping ()->Void) -> Int? {

        //create error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open the custom connection
            if let err = SQLiteDB.sharedInstance.openWithFlags(flags.toSQL()) {
                error = err
                return
            }

            //execute the closure
            closure()

            //close the custom connection
            if let err = SQLiteDB.sharedInstance.closeCustomConnection() {
                error = err
                return
            }

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }


    // MARK: - Escaping Objects

    /**
    Escape an object to be inserted into a SQLite statement as a value

    NOTE: Supported object types are: String, Int, Double, Bool, NSData, NSDate, and nil. All other data types will return the String value "NULL", and a warning message will be printed.

    - parameter obj:  The value to be escaped

    - returns:    The escaped value as a String, ready to be inserted into a SQL statement. Note: Single quotes (') will be placed around the entire value, if necessary.
    */
    public static func escapeValue(_ obj: AnyObject?) -> String {

        return SQLiteDB.sharedInstance.escapeValue(obj)
    }

    /**
    Escape a string to be inserted into a SQLite statement as an indentifier (e.g. table or column name)

    - parameter obj:  The identifier to be escaped. NOTE: This object must be of type String.

    - returns:    The escaped identifier as a String, ready to be inserted into a SQL statement. Note: Double quotes (") will be placed around the entire identifier.
    */
    public static func escapeIdentifier(_ obj: String) -> String {

        return SQLiteDB.sharedInstance.escapeIdentifier(obj)
    }


    // MARK: - Tables

    /**
    Create A Table With The Provided Column Names and Types

    Note: The ID field is created automatically as "INTEGER PRIMARY KEY AUTOINCREMENT"

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter  table:                The table name to be created
    - parameter  columnNamesAndTypes:  A dictionary where the key = column name, and the value = data type

    - returns:                     An Int with the error code, or nil if there was no error
    */
    public static func createTable(_ table: String, withColumnNamesAndTypes values: [String: SwiftData.DataType]) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the statement
            error = SQLiteDB.sharedInstance.createSQLTable(table, withColumnsAndTypes: values)

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Delete a SQLite table by name

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter  table:  The table name to be deleted

    - returns:       An Int with the error code, or nil if there was no error
    */
    public static func deleteTable(_ table: String) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the statement
            error = SQLiteDB.sharedInstance.deleteSQLTable(table)

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Obtain a list of the existing SQLite table names

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - Table query error (403)

    - returns:  A tuple containing an Array of all existing SQLite table names, and an Int with the error code or nil if there was no error
    */
    public static func existingTables() -> (result: [String], error: Int?) {

        //create result and error variables
        var result = [String] ()
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the statement
            (result, error) = SQLiteDB.sharedInstance.existingTables()

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }


    // MARK: - Misc


    /**
    Obtain the error message relating to the provided error code

    - parameter code:  The error code provided

    - returns:     The error message relating to the provided error code
    */
    public static func errorMessageForCode(_ code: Int) -> String {

        return SwiftData.SDError.errorMessageFromCode(code)
    }

    /**
    Obtain the database path

    - returns:  The path to the SwiftData database
    */
    public static func databasePath() -> String {

        return SQLiteDB.sharedInstance.dbPath
    }

    /**
    Obtain the last inserted row id

    Note: Care should be taken when the database is being accessed from multiple threads. The value could possibly return the last inserted row ID for another operation if another thread executes after your intended operation but before this function call.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - returns:  A tuple of he ID of the last successfully inserted row's, and an Int of the error code or nil if there was no error
    */
    public static func lastInsertedRowID() -> (rowID: Int, error: Int?) {

        //create result and error variables
        var result = 0
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //find the last inserted row id
            result = SQLiteDB.sharedInstance.lastInsertedRowID()

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }

    /**
    Obtain the number of rows modified by the most recently completed SQLite statement (INSERT, UPDATE, or DELETE)

    Note: Care should be taken when the database is being accessed from multiple threads. The value could possibly return the number of rows modified for another operation if another thread executes after your intended operation but before this function call.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - returns:  A tuple of the number of rows modified by the most recently completed SQLite statement, and an Int with the error code or nil if there was no error
    */
    public static func numberOfRowsModified() -> (rowID: Int, error: Int?) {

        //create result and error variables
        var result = 0
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //find the number of rows modified
            result = SQLiteDB.sharedInstance.numberOfRowsModified()

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }


    // MARK: - Indexes

    /**
    Create a SQLite index on the specified table and column(s)

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - Index error (401)

    - parameter name:       The index name that is being created
    - parameter onColumns:  An array of column names that the index will be applied to (must be one column or greater)
    - parameter inTable:    The table name where the index is being created
    - parameter isUnique:   True if the index should be unique, false if it should not be unique (defaults to false)

    - returns:          An Int with the error code, or nil if there was no error
    */
    public static func createIndex(name: String, onColumns: [String], inTable: String, isUnique: Bool = false) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //create the index
            error = SQLiteDB.sharedInstance.createIndex(name, columns: onColumns, table: inTable, unique: isUnique)

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Remove a SQLite index by its name

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter indexName:  The name of the index to be removed

    - returns:          An Int with the error code, or nil if there was no error
    */
    public static func removeIndex(_ indexName: String) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //remove the index
            error = SQLiteDB.sharedInstance.removeIndex(indexName)

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Obtain a list of all existing indexes

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - Index error (402)

    - returns:  A tuple containing an Array of all existing index names on the SQLite database, and an Int with the error code or nil if there was no error
    */
    public static func existingIndexes() -> (result: [String], error: Int?) {

        //create the result and error variables
        var result = [String] ()
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the statement
            (result, error) = SQLiteDB.sharedInstance.existingIndexes()

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }

    /**
    Obtain a list of all existing indexes on a specific table

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - Index error (402)

    - parameter  table:  The name of the table that is being queried for indexes

    - returns:       A tuple containing an Array of all existing index names in the table, and an Int with the error code or nil if there was no error
    */
    public static func existingIndexesForTable(_ table: String) -> (result: [String], error: Int?) {

        //create the result and error variables
        var result = [String] ()
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //execute the statement
            (result, error) = SQLiteDB.sharedInstance.existingIndexesForTable(table)

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return (result, error)
    }


    // MARK: - Transactions and Savepoints

    /**
    Execute commands within a single exclusive transaction

    A connection to the database is opened and is not closed until the end of the transaction. A transaction cannot be embedded into another transaction or savepoint.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)
    - Transaction errors (501 - 502)

    - parameter transactionClosure:  A closure containing commands that will execute as part of a single transaction. If the transactionClosure returns true, the changes made within the closure will be committed. If false, the changes will be rolled back and will not be saved.

    - returns:                   An Int with the error code, or nil if there was no error committing or rolling back the transaction
    */
    public static func transaction(_ transactionClosure: @escaping ()->Bool) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //begin the transaction
            if let err = SQLiteDB.sharedInstance.beginTransaction() {
                SQLiteDB.sharedInstance.close()
                error = err
                return
            }

            //execute the transaction closure
            if transactionClosure() {
                if let err = SQLiteDB.sharedInstance.commitTransaction() {
                    error = err
                }
            } else {
                if let err = SQLiteDB.sharedInstance.rollbackTransaction() {
                    error = err
                }
            }

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Execute commands within a single savepoint

    A connection to the database is opened and is not closed until the end of the savepoint (or the end of the last savepoint, if embedded).

    NOTE: Unlike transactions, savepoints may be embedded into other savepoints or transactions.

    Possible errors returned by this function are:

    - SQLite errors (0 - 101)

    - parameter savepointClosure:  A closure containing commands that will execute as part of a single savepoint. If the savepointClosure returns true, the changes made within the closure will be released. If false, the changes will be rolled back and will not be saved.

    - returns:                 An Int with the error code, or nil if there was no error releasing or rolling back the savepoint
    */
    public static func savepoint(_ savepointClosure: @escaping ()->Bool) -> Int? {

        //create the error variable
        var error: Int? = nil

        //create task closure
        let task: ()->Void = {

            //open database connection
            if let err = SQLiteDB.sharedInstance.open() {
                error = err
                return
            }

            //begin the savepoint
            if let err = SQLiteDB.sharedInstance.beginSavepoint() {
                SQLiteDB.sharedInstance.close()
                error = err
                return
            }

            //execute the savepoint closure
            if savepointClosure() {
                if let err = SQLiteDB.sharedInstance.releaseSavepoint() {
                    error = err
                }
            } else {
                if let err = SQLiteDB.sharedInstance.rollbackSavepoint() {
                    print("Error rolling back to savepoint")
                    SQLiteDB.sharedInstance.savepointsOpen -= 1
                    SQLiteDB.sharedInstance.close()
                    error = err
                    return
                }
                if let err = SQLiteDB.sharedInstance.releaseSavepoint() {
                    error = err
                }
            }

            //close the database connection
            SQLiteDB.sharedInstance.close()

        }

        //execute the task on the current thread if in a transaction, savepoint, or closure. Otherwise, add the task to the database queue
        if SQLiteDB.sharedInstance.inTransaction || SQLiteDB.sharedInstance.savepointsOpen > 0 || SQLiteDB.sharedInstance.openWithFlags {
            task()
        } else {
            SQLiteDB.sharedInstance.queue.sync {
                task()
            }
        }

        return error
    }

    /**
    Convenience function to save a UIImage to disk and return the ID

    - parameter image:  The UIImage to be saved

    - returns:      The ID of the saved image as a String, or nil if there was an error saving the image to disk
    */
    public static func saveUIImage(_ image: UIImage) -> String? {

        let docsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        let imageDirPath = docsPath.stringByAppendingPathComponent("SwiftDataImages")

        if !FileManager.default.fileExists(atPath: imageDirPath) {
            do {
                try FileManager.default.createDirectory(atPath: imageDirPath, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
                print("Error creating SwiftData image folder")
                return nil
            }
        }

        let imageID = UUID().uuidString

        let imagePath = imageDirPath.stringByAppendingPathComponent(imageID)

        let imageAsData = image.pngData()
        if !((try? imageAsData!.write(to: URL(fileURLWithPath: imagePath), options: [.atomic])) != nil) {
            print("Error saving image")
            return nil
        }

        return imageID

    }

    /**
    Convenience function to delete a UIImage with the specified ID

    - parameter id:  The id of the UIImage

    - returns:   True if the image was successfully deleted, or false if there was an error during the deletion
    */
    public static func deleteUIImageWithID(_ id: String) -> Bool {

        let docsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        let imageDirPath = docsPath.stringByAppendingPathComponent("SwiftDataImages")
        let fullPath = imageDirPath.stringByAppendingPathComponent(id)

        do {
            try FileManager.default.removeItem(atPath: fullPath)
            return true
        } catch _ {
            return false
        }

    }


    // MARK: - SQLiteDB Class

    fileprivate class SQLiteDB {

        //create a single instance of SQLiteDB
        class var sharedInstance: SQLiteDB {
            struct Singleton {
                static let instance = SQLiteDB()
            }
            return Singleton.instance
        }

        //declare SQLiteDB properties
        var sqliteDB: OpaquePointer? = nil
        var dbPath = SQLiteDB.createPath()
        var inTransaction = false
        var isConnected = false
        var openWithFlags = false
        var savepointsOpen = 0
        let queue = DispatchQueue(label: "SwiftData.DatabaseQueue", attributes: [])


        // MARK: - Database Handling Functions

        //open a connection to the sqlite3 database
        func open() -> Int? {

            //check if in a transaction
            if inTransaction || openWithFlags || savepointsOpen > 0 {
                return nil
            }

            //check if connection is already open
            if sqliteDB != nil || isConnected {
                return nil
            }

            //open connection
            let status = sqlite3_open(dbPath.cString(using: String.Encoding.utf8)!, &sqliteDB)
            if status != SQLITE_OK {
                print("SwiftData Error -> During: Opening Database")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                return Int(status)
            }

            isConnected = true

            return nil
        }

        //open a connection to the sqlite3 database with flags
        func openWithFlags(_ flags: Int32) -> Int? {

            //check if in transaction
            if inTransaction {
                print("SwiftData Error -> During: Opening Database with Flags")
                print("                -> Code: 302 - Cannot open a custom connection inside a transaction")
                return 302
            }

            //check if already openWithFlags
            if openWithFlags {
                print("SwiftData Error -> During: Opening Database with Flags")
                print("                -> Code: 301 - A custom connection is already open")
                return 301
            }

            //check if in savepoint
            if savepointsOpen > 0 {
                print("SwiftData Error -> During: Opening Database with Flags")
                print("                -> Code: 303 - Cannot open a custom connection inside a savepoint")
                return 303
            }

            //check if already opened
            if isConnected {
                print("SwiftData Error -> During: Opening Database with Flags")
                print("                -> Code: 301 - A custom connection is already open")
                return 301
            }

            //open the connection
            let status = sqlite3_open_v2(dbPath.cString(using: String.Encoding.utf8)!, &sqliteDB, flags, nil)
            if status != SQLITE_OK {
                print("SwiftData Error -> During: Opening Database with Flags")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                return Int(status)
            }

            isConnected = true
            openWithFlags = true

            return nil
        }

        //close the connection to to the sqlite3 database
        func close() {

            //check if in transaction
            if inTransaction || openWithFlags || savepointsOpen > 0 {
                return
            }

            //check if connection is already closed
            if sqliteDB == nil || !isConnected {
                return
            }

            //close connection
            let status = sqlite3_close(sqliteDB)
            if status != SQLITE_OK {
                print("SwiftData Error -> During: Closing Database")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
            }

            sqliteDB = nil
            isConnected = false
        }

        //close a custom connection to the sqlite3 database
        func closeCustomConnection() -> Int? {

            //check if in trasaction
            if inTransaction {
                print("SwiftData Error -> During: Closing Database with Flags")
                print("                -> Code: 305 - Cannot close a custom connection inside a transaction")
                return 305
            }

            //check if in savepoint
            if savepointsOpen > 0 {
                print("SwiftData Error -> During: Closing Database with Flags")
                print("                -> Code: 306 - Cannot close a custom connection inside a savepoint")
                return 306
            }

            //check if no custom connectino open
            if !openWithFlags {
                print("SwiftData Error -> During: Closing Database with Flags")
                print("                -> Code: 304 - A custom connection is not currently open")
                return 304
            }

            //close connection
            let status = sqlite3_close(sqliteDB)

            sqliteDB = nil
            isConnected = false
            openWithFlags = false

            if status != SQLITE_OK {
                print("SwiftData Error -> During: Closing Database with Flags")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                return Int(status)
            }

            return nil
        }

        //create the database path
        class func createPath() -> String {

            let docsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
            let databaseStr = "SwiftData.sqlite"
            let dbPath = docsPath.stringByAppendingPathComponent(databaseStr)

            return dbPath
        }

        //begin a transaction
        func beginTransaction() -> Int? {

            if savepointsOpen > 0 {
                print("SwiftData Error -> During: Beginning Transaction")
                print("                -> Code: 501 - Cannot begin a transaction within a savepoint")
                return 501
            }

            if inTransaction {
                print("SwiftData Error -> During: Beginning Transaction")
                print("                -> Code: 502 - Cannot begin a transaction within another transaction")
                return 502
            }

            if let error = executeChange("BEGIN EXCLUSIVE") {
                return error
            }

            inTransaction = true

            return nil

        }

        //rollback a transaction
        func rollbackTransaction() -> Int? {

            let error = executeChange("ROLLBACK")

            inTransaction = false

            return error
        }

        //commit a transaction
        func commitTransaction() -> Int? {

            let error = executeChange("COMMIT")

            inTransaction = false

            if let err = error {
                rollbackTransaction()
                return err
            }

            return nil
        }

        //begin a savepoint
        func beginSavepoint() -> Int? {

            if let error = executeChange("SAVEPOINT 'savepoint\(savepointsOpen + 1)'") {
                return error
            }

            savepointsOpen += 1

            return nil
        }

        //rollback a savepoint
        func rollbackSavepoint() -> Int? {

            return executeChange("ROLLBACK TO 'savepoint\(savepointsOpen)'")
        }

        //release a savepoint
        func releaseSavepoint() -> Int? {

            let error = executeChange("RELEASE 'savepoint\(savepointsOpen)'")

            savepointsOpen -= 1

            return error
        }

        //get last inserted row id
        func lastInsertedRowID() -> Int {
            let id = sqlite3_last_insert_rowid(sqliteDB)
            return Int(id)
        }

        //number of rows changed by last update
        func numberOfRowsModified() -> Int {

            return Int(sqlite3_changes(sqliteDB))
        }

        //return value of column
        func getColumnValue(_ statement: OpaquePointer, index: Int32, type: String) -> AnyObject? {

            switch type {
            case "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT", "BIGINT", "UNSIGNED BIG INT", "INT2", "INT8":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil
                }
                return Int(sqlite3_column_int(statement, index)) as AnyObject
            case "CHARACTER(20)", "VARCHAR(255)", "VARYING CHARACTER(255)", "NCHAR(55)", "NATIVE CHARACTER", "NVARCHAR(100)", "TEXT", "CLOB":
                let text = sqlite3_column_text(statement, index)
                return String(cString: text!) as AnyObject
            case "BLOB", "NONE":
                let blob = sqlite3_column_blob(statement, index)
                if blob != nil {
                    let size = sqlite3_column_bytes(statement, index)
                    return Data(bytes: UnsafeRawPointer(blob)!, count: Int(size)) as AnyObject
                }
                return nil
            case "REAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT", "NUMERIC", "DECIMAL(10,5)":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil
                }
                return Double(sqlite3_column_double(statement, index)) as AnyObject
            case "BOOLEAN":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil
                }
                return (sqlite3_column_int(statement, index) != Int32(0)) as AnyObject
            case "DATE", "DATETIME":
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let text = String(cString: sqlite3_column_text(statement, index))
                return dateFormatter.date(from: text) as AnyObject
//                print("SwiftData Warning -> The text date at column: \(index) could not be cast as a String, returning nil")
//                return nil
            default:
                print("SwiftData Warning -> Column: \(index) is of an unrecognized type, returning nil")
                return nil
            }

        }


        // MARK: SQLite Execution Functions

        //execute a SQLite update from a SQL String
        func executeChange(_ sqlStr: String, withArgs: [AnyObject]? = nil) -> Int? {

            var sql = sqlStr
            if let args = withArgs {
                let result = bind(args, toSQL: sql)
                if let error = result.error {
                    return error
                } else {
                    sql = result.string
                }
            }

            var pStmt: OpaquePointer? = nil
            var status = sqlite3_prepare_v2(SQLiteDB.sharedInstance.sqliteDB, sql, -1, &pStmt, nil)
            if status != SQLITE_OK {
                print("SwiftData Error -> During: SQL Prepare")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                sqlite3_finalize(pStmt)
                return Int(status)
            }

            status = sqlite3_step(pStmt)
            if status != SQLITE_DONE && status != SQLITE_OK {
                print("SwiftData Error -> During: SQL Step")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                sqlite3_finalize(pStmt)
                return Int(status)
            }

            sqlite3_finalize(pStmt)

            return nil
        }

        //execute a SQLite query from a SQL String
        func executeQuery(_ sqlStr: String, withArgs: [AnyObject]? = nil) -> (result: [SDRow], error: Int?) {

            var resultSet = [SDRow]()

            var sql = sqlStr
            if let args = withArgs {
                let result = bind(args, toSQL: sql)
                if let err = result.error {
                    return (resultSet, err)
                } else {
                    sql = result.string
                }
            }

            var pStmt: OpaquePointer? = nil
            var status = sqlite3_prepare_v2(SQLiteDB.sharedInstance.sqliteDB, sql, -1, &pStmt, nil)
            if status != SQLITE_OK {
                print("SwiftData Error -> During: SQL Prepare")
                print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                    print("                -> Details: \(errMsg)")
                }
                sqlite3_finalize(pStmt)
                return (resultSet, Int(status))
            }

            var columnCount: Int32 = 0
            var next = true
            while next {
                status = sqlite3_step(pStmt)
                if status == SQLITE_ROW {
                    columnCount = sqlite3_column_count(pStmt)
                    var row = SDRow()
                    for i: Int32 in 0 ..< columnCount {
                    //for var i: Int32 = 0; i < columnCount; ++i {
                        let columnName = String(cString: sqlite3_column_name(pStmt, i))
                        if let columnType = String(validatingUTF8: sqlite3_column_decltype(pStmt, i))?.uppercased() {
                            if let columnValue: AnyObject = getColumnValue(pStmt!, index: i, type: columnType) {
                                row[columnName] = SDColumn(obj: columnValue)
                            }
                        } else {
                            var columnType = ""
                            switch sqlite3_column_type(pStmt, i) {
                            case 1:
                                columnType = "INTEGER"
                            case 2:
                                columnType = "FLOAT"
                            case 3:
                                columnType = "TEXT"
                            case 4:
                                columnType = "BLOB"
                            case 5:
                                columnType = "NULL"
                            default:
                                columnType = "NULL"
                            }
                            if let columnValue: AnyObject = getColumnValue(pStmt!, index: i, type: columnType) {
                                row[columnName] = SDColumn(obj: columnValue)
                            }
                        }
                    }
                    resultSet.append(row)
                } else if status == SQLITE_DONE {
                    next = false
                } else {
                    print("SwiftData Error -> During: SQL Step")
                    print("                -> Code: \(status) - " + SDError.errorMessageFromCode(Int(status)))
                    if let errMsg = String(validatingUTF8: sqlite3_errmsg(SQLiteDB.sharedInstance.sqliteDB)) {
                        print("                -> Details: \(errMsg)")
                    }
                    sqlite3_finalize(pStmt)
                    return (resultSet, Int(status))
                }

            }

            sqlite3_finalize(pStmt)

            return (resultSet, nil)
        }

    }


    // MARK: - SDRow

    public struct SDRow {

        //declare properties
        var values = [String: SDColumn]()

        //subscript
        public subscript(key: String) -> SDColumn? {
            get {
                return values[key]
            }
            set(newValue) {
                values[key] = newValue
            }
        }

    }


    // MARK: - SDColumn

    public struct SDColumn {

        //declare property
        var value: AnyObject

        //initialization
        init(obj: AnyObject) {
            value = obj
        }

        //return value by type

        /**
        Return the column value as a String

        - returns:  An Optional String corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as a String, or the value is NULL
        */
        public func asString() -> String? {
            return value as? String
        }

        /**
        Return the column value as an Int

        - returns:  An Optional Int corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as a Int, or the value is NULL
        */
        public func asInt() -> Int? {
            return value as? Int
        }

        /**
        Return the column value as a Double

        - returns:  An Optional Double corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as a Double, or the value is NULL
        */
        public func asDouble() -> Double? {
            return value as? Double
        }

        /**
        Return the column value as a Bool

        - returns:  An Optional Bool corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as a Bool, or the value is NULL
        */
        public func asBool() -> Bool? {
            return value as? Bool
        }

        /**
        Return the column value as NSData

        - returns:  An Optional NSData object corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as NSData, or the value is NULL
        */
        public func asData() -> Data? {
            return value as? Data
        }

        /**
        Return the column value as an NSDate

        - returns:  An Optional NSDate corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as an NSDate, or the value is NULL
        */
        public func asDate() -> Date? {
            return value as? Date
        }

        /**
        Return the column value as an AnyObject

        - returns:  An Optional AnyObject corresponding to the apprioriate column value. Will be nil if: the column name does not exist, the value cannot be cast as an AnyObject, or the value is NULL
        */
        public func asAnyObject() -> AnyObject? {
            return value
        }

        /**
        Return the column value path as a UIImage

        - returns:  An Optional UIImage corresponding to the path of the apprioriate column value. Will be nil if: the column name does not exist, the value of the specified path cannot be cast as a UIImage, or the value is NULL
        */
        public func asUIImage() -> UIImage? {
            if let path = value as? String{
                let docsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
                let imageDirPath = docsPath.stringByAppendingPathComponent("SwiftDataImages")
                let fullPath = imageDirPath.stringByAppendingPathComponent(path)
                if !FileManager.default.fileExists(atPath: fullPath) {
                    print("SwiftData Error -> Invalid image ID provided")
                    return nil
                }
                let imageAsData = try? Data(contentsOf: URL(fileURLWithPath: fullPath))
                if let imageAsData = imageAsData {
                    return UIImage(data: imageAsData)
                }
            }
            return nil
        }

    }


    // MARK: - Error Handling

    fileprivate struct SDError {

    }

}


// MARK: - Escaping And Binding Functions

extension SwiftData.SQLiteDB {

    //bind object
    func bind(_ objects: [AnyObject], toSQL sql: String) -> (string: String, error: Int?) {

        var newSql = ""
        var bindIndex = 0
        var i = false
        for char in sql {
            if char == "?" {
                if bindIndex > objects.count - 1 {
                    print("SwiftData Error -> During: Object Binding")
                    print("                -> Code: 201 - Not enough objects to bind provided")
                    return ("", 201)
                }
                var obj = ""
                if i {
                    if let str = objects[bindIndex] as? String {
                        obj = escapeIdentifier(str)
                    } else {
                        print("SwiftData Error -> During: Object Binding")
                        print("                -> Code: 203 - Object to bind as identifier must be a String at array location: \(bindIndex)")
                        return ("", 203)
                    }
                    newSql = newSql.substring(to: newSql.index(before: newSql.endIndex))
                } else {
                    obj = escapeValue(objects[bindIndex])
                }
                newSql += obj
                bindIndex += 1
            } else {
                newSql.append(char)
            }
            if char == "i" {
                i = true
            } else if i {
                i = false
            }
        }

        if bindIndex != objects.count {
            print("SwiftData Error -> During: Object Binding")
            print("                -> Code: 202 - Too many objects to bind provided")
            return ("", 202)
        }

        return (newSql, nil)
    }

    //return escaped String value of AnyObject
    func escapeValue(_ obj: AnyObject?) -> String {

        if let obj: AnyObject = obj {

            if obj is String {
                return "'\(escapeStringValue(obj as! String))'"
            }

            if obj is Double || obj is Int {
                return "\(obj)"
            }

            if obj is Bool {
                if obj as! Bool {
                    return "1"
                } else {
                    return "0"
                }
            }

            if obj is Data {
                let str = "\(obj)"
                var newStr = ""
                for char in str {
                    if char != "<" && char != ">" && char != " " {
                        newStr.append(char)
                    }
                }

                return "X'\(newStr)'"
            }

            if obj is Date {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return "\(escapeValue(dateFormatter.string(from: obj as! Date) as AnyObject))"
            }

            if obj is UIImage {
                if let imageID = SD.saveUIImage(obj as! UIImage) {
                    return "'\(escapeStringValue(imageID))'"
                }
                print("SwiftData Warning -> Cannot save image, NULL will be inserted into the database")
                return "NULL"
            }

            print("SwiftData Warning -> Object \"\(obj)\" is not a supported type and will be inserted into the database as NULL")
            return "NULL"

        } else {
            return "NULL"
        }

    }

    //return escaped String identifier
    func escapeIdentifier(_ obj: String) -> String {

        return "\"\(escapeStringIdentifier(obj))\""

    }


    //escape string
    func escapeStringValue(_ str: String) -> String {
        var escapedStr = ""
        for char in str {
            if char == "'" {
                escapedStr += "'"
            }
            escapedStr.append(char)
        }

        return escapedStr
    }

    //escape string
    func escapeStringIdentifier(_ str: String) -> String {
        var escapedStr = ""
        for char in str {
            if char == "\"" {
                escapedStr += "\""
            }
            escapedStr.append(char)
        }

        return escapedStr
    }

}


// MARK: - SQL Creation Functions

extension SwiftData {

    /**
    Column Data Types

    - parameter  StringVal:   A column with type String, corresponds to SQLite type "TEXT"
    - parameter  IntVal:      A column with type Int, corresponds to SQLite type "INTEGER"
    - parameter  DoubleVal:   A column with type Double, corresponds to SQLite type "DOUBLE"
    - parameter  BoolVal:     A column with type Bool, corresponds to SQLite type "BOOLEAN"
    - parameter  DataVal:     A column with type NSdata, corresponds to SQLite type "BLOB"
    - parameter  DateVal:     A column with type NSDate, corresponds to SQLite type "DATE"
    - parameter  UIImageVal:  A column with type String (the path value of saved UIImage), corresponds to SQLite type "TEXT"
    */
    public enum DataType {

        case stringVal
        case intVal
        case doubleVal
        case boolVal
        case dataVal
        case dateVal
        case uiImageVal

        fileprivate func toSQL() -> String {

            switch self {

            case .stringVal, .uiImageVal:
                return "TEXT"
            case .intVal:
                return "INTEGER"
            case .doubleVal:
                return "DOUBLE"
            case .boolVal:
                return "BOOLEAN"
            case .dataVal:
                return "BLOB"
            case .dateVal:
                return "DATE"
            }
        }

    }

    /**
    Flags for custom connection to the SQLite database

    - parameter  ReadOnly:         Opens the SQLite database with the flag "SQLITE_OPEN_READONLY"
    - parameter  ReadWrite:        Opens the SQLite database with the flag "SQLITE_OPEN_READWRITE"
    - parameter  ReadWriteCreate:  Opens the SQLite database with the flag "SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE"
    */
    public enum Flags {

        case readOnly
        case readWrite
        case readWriteCreate

        fileprivate func toSQL() -> Int32 {

            switch self {
            case .readOnly:
                return SQLITE_OPEN_READONLY
            case .readWrite:
                return SQLITE_OPEN_READWRITE
            case .readWriteCreate:
                return SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
            }

        }

    }

}


extension SwiftData.SQLiteDB {

    //create a table
    func createSQLTable(_ table: String, withColumnsAndTypes values: [String: SwiftData.DataType]) -> Int? {

        //form the SQLite string for creation of the actual table
        var sqlStr = "CREATE TABLE \(table) (ID INTEGER PRIMARY KEY AUTOINCREMENT, "
        var firstRun = true
        for value in values {
            if firstRun {
                sqlStr += "\(escapeIdentifier(value.0)) \(value.1.toSQL())"
                firstRun = false
            } else {
                sqlStr += ", \(escapeIdentifier(value.0)) \(value.1.toSQL())"
            }
        }
        sqlStr += ")"

        //execute update to create new table
        return executeChange(sqlStr)
    }

    //delete a table
    func deleteSQLTable(_ table: String) -> Int? {

        //form the SQLite string for deletion of the table
        let sqlStr = "DROP TABLE \(table)"

        //execute update to delete table
        return executeChange(sqlStr)
    }

    //get existing table names
    func existingTables() -> (result: [String], error: Int?) {
        let sqlStr = "SELECT name FROM sqlite_master WHERE type = 'table'"
        var tableArr = [String]()
        let results = executeQuery(sqlStr)
        if let err = results.error {
            return (tableArr, err)
        }
        for row in results.result {
            if let table = row["name"]?.asString() {
                tableArr.append(table)
            } else {
                print("SwiftData Error -> During: Finding Existing Tables")
                print("                -> Code: 403 - Error extracting table names from sqlite_master")
                return (tableArr, 403)
            }
        }

        return (tableArr, nil)
    }

    //create an index
    func createIndex(_ name: String, columns: [String], table: String, unique: Bool) -> Int? {

        if columns.count < 1 {
            print("SwiftData Error -> During: Creating Index")
            print("                -> Code: 401 - At least one column name must be provided")
            return 401
        }

        var sqlStr = ""
        if unique {
            sqlStr = "CREATE UNIQUE INDEX \(name) ON \(table) ("
        } else {
            sqlStr = "CREATE INDEX \(name) ON \(table) ("
        }
        var firstRun = true
        for column in columns {
            if firstRun {
                sqlStr += column
                firstRun = false
            } else {
                sqlStr += ", \(column)"
            }
        }
        sqlStr += ")"

        return executeChange(sqlStr)
    }

    //remove an index
    func removeIndex(_ name: String) -> Int? {

        let sqlStr = "DROP INDEX \(name)"

        return executeChange(sqlStr)
    }

    //obtain list of existing indexes
    func existingIndexes() -> (result: [String], error: Int?) {

        let sqlStr = "SELECT name FROM sqlite_master WHERE type = 'index'"

        var indexArr = [String]()
        let results = executeQuery(sqlStr)
        if let err = results.error {
            return (indexArr, err)
        }
        for res in results.result {
            if let index = res["name"]?.asString() {
                indexArr.append(index)
            } else {
                print("SwiftData Error -> During: Finding Existing Indexes")
                print("                -> Code: 402 - Error extracting index names from sqlite_master")
                print("Error finding existing indexes -> Error extracting index names from sqlite_master")
                return (indexArr, 402)
            }
        }
        return (indexArr, nil)
    }

    //obtain list of existing indexes for a specific table
    func existingIndexesForTable(_ table: String) -> (result: [String], error: Int?) {

        let sqlStr = "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = '\(table)'"

        var indexArr = [String]()
        let results = executeQuery(sqlStr)
        if let err = results.error {
            return (indexArr, err)
        }
        for res in results.result {
            if let index = res["name"]?.asString() {
                indexArr.append(index)
            } else {
                print("SwiftData Error -> During: Finding Existing Indexes for a Table")
                print("                -> Code: 402 - Error extracting index names from sqlite_master")
                return (indexArr, 402)
            }
        }
        return (indexArr, nil)
    }

}


// MARK: - SDError Functions

extension SwiftData.SDError {

    //get the error message from the error code
    fileprivate static func errorMessageFromCode(_ errorCode: Int) -> String {

        switch errorCode {

        //no error

        case -1:
            return "No error"

        //SQLite error codes and descriptions as per: http://www.sqlite.org/c3ref/c_abort.html
        case 0:
            return "Successful result"
        case 1:
            return "SQL error or missing database"
        case 2:
            return "Internal logic error in SQLite"
        case 3:
            return "Access permission denied"
        case 4:
            return "Callback routine requested an abort"
        case 5:
            return "The database file is locked"
        case 6:
            return "A table in the database is locked"
        case 7:
            return "A malloc() failed"
        case 8:
            return "Attempt to write a readonly database"
        case 9:
            return "Operation terminated by sqlite3_interrupt()"
        case 10:
            return "Some kind of disk I/O error occurred"
        case 11:
            return "The database disk image is malformed"
        case 12:
            return "Unknown opcode in sqlite3_file_control()"
        case 13:
            return "Insertion failed because database is full"
        case 14:
            return "Unable to open the database file"
        case 15:
            return "Database lock protocol error"
        case 16:
            return "Database is empty"
        case 17:
            return "The database schema changed"
        case 18:
            return "String or BLOB exceeds size limit"
        case 19:
            return "Abort due to constraint violation"
        case 20:
            return "Data type mismatch"
        case 21:
            return "Library used incorrectly"
        case 22:
            return "Uses OS features not supported on host"
        case 23:
            return "Authorization denied"
        case 24:
            return "Auxiliary database format error"
        case 25:
            return "2nd parameter to sqlite3_bind out of range"
        case 26:
            return "File opened that is not a database file"
        case 27:
            return "Notifications from sqlite3_log()"
        case 28:
            return "Warnings from sqlite3_log()"
        case 100:
            return "sqlite3_step() has another row ready"
        case 101:
            return "sqlite3_step() has finished executing"

        //custom SwiftData errors

        //->binding errors

        case 201:
            return "Not enough objects to bind provided"
        case 202:
            return "Too many objects to bind provided"
        case 203:
            return "Object to bind as identifier must be a String"

        //->custom connection errors

        case 301:
            return "A custom connection is already open"
        case 302:
            return "Cannot open a custom connection inside a transaction"
        case 303:
            return "Cannot open a custom connection inside a savepoint"
        case 304:
            return "A custom connection is not currently open"
        case 305:
            return "Cannot close a custom connection inside a transaction"
        case 306:
            return "Cannot close a custom connection inside a savepoint"

        //->index and table errors

        case 401:
            return "At least one column name must be provided"
        case 402:
            return "Error extracting index names from sqlite_master"
        case 403:
            return "Error extracting table names from sqlite_master"

        //->transaction and savepoint errors

        case 501:
            return "Cannot begin a transaction within a savepoint"
        case 502:
            return "Cannot begin a transaction within another transaction"

        //unknown error

        default:
            //what the fuck happened?!?
            return "Unknown error"
        }

    }

}

public typealias SD = SwiftData

extension String {

    var lastPathComponent: String {

        get {
            return (self as NSString).lastPathComponent
        }
    }
    var pathExtension: String {

        get {

            return (self as NSString).pathExtension
        }
    }
    var stringByDeletingLastPathComponent: String {

        get {

            return (self as NSString).deletingLastPathComponent
        }
    }
    var stringByDeletingPathExtension: String {

        get {

            return (self as NSString).deletingPathExtension
        }
    }
    var pathComponents: [String] {

        get {

            return (self as NSString).pathComponents
        }
    }

    func stringByAppendingPathComponent(_ path: String) -> String {

        let nsSt = self as NSString

        return nsSt.appendingPathComponent(path)
    }

    func stringByAppendingPathExtension(_ ext: String) -> String? {

        let nsSt = self as NSString

        return nsSt.appendingPathExtension(ext)
    }
}
