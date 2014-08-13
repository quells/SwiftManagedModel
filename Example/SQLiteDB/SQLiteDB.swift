//
//  SQLiteDB.swift
//  TasksGalore
//
//  Created by Fahim Farook on 12/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation
import UIKit

private let SQLITE_DATE = SQLITE_NULL + 1

/**
Property of an SQLRow.

Possible Value Types:

- Integer
- Double
- String
- Data
- Date
- Null
*/
public class SQLColumn: Printable {
    
    private var _value: AnyObject! = nil
    private var _type: CInt = -1
    
    init(value: AnyObject, type: CInt) {
        self._value = value
        self._type = type
    }
    
    public var value: AnyObject! {
        get {
            switch self.type {
            case .Integer: if _value { return _value as Int } else { return 0 }
            case .Double: if _value { return _value as Double } else { return 0 }
            case .Data: if _value { return _value as NSData } else { return nil }
            case .Null: return nil
            case .Date: if _value { return _value as NSDate } else { return nil }
            default: if _value { return _value as String } else { return "" }
            }
        }
    }
    
    public func valueAsString() -> String {
        switch (self._type) {
        case SQLITE_INTEGER, SQLITE_FLOAT: return "\(self._value)"
        case SQLITE_TEXT: return self._value as String
        case SQLITE_BLOB: return NSString(data: self._value as NSData, encoding: NSUTF8StringEncoding)
        case SQLITE_NULL: return ""
        case SQLITE_DATE:
            let df = NSDateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.stringFromDate(self._value as NSDate)
        default: return ""
        }
    }
    
    public func valueAsInt() -> Int {
        switch (self._type) {
        case SQLITE_INTEGER, SQLITE_FLOAT: return self._value as Int
        case SQLITE_TEXT: return (self._value as NSString).integerValue
        case SQLITE_BLOB: return NSString(data: self._value as NSData, encoding: NSUTF8StringEncoding).integerValue
        case SQLITE_NULL: return 0
        case SQLITE_DATE: return Int((value as NSDate).timeIntervalSince1970)
        default: return 0
        }
    }
    
    public func valueAsDouble() -> Double {
        switch (self._type) {
        case SQLITE_INTEGER, SQLITE_FLOAT: return value as Double
        case SQLITE_TEXT: return (self._value as NSString).doubleValue
        case SQLITE_BLOB: return NSString(data: self._value as NSData, encoding: NSUTF8StringEncoding).doubleValue
        case SQLITE_NULL: return 0.0
        case SQLITE_DATE: return (value as NSDate).timeIntervalSince1970
        default: return 0.0
        }
    }
    
    public func valueAsData() -> NSData? {
        switch (self._type) {
        case SQLITE_INTEGER, SQLITE_FLOAT: return ("\(self._value)" as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        case SQLITE_TEXT: return (value as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        case SQLITE_BLOB: return value as? NSData
        case SQLITE_NULL: return nil
        case SQLITE_DATE:
            let df = NSDateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.stringFromDate(self._value as NSDate).dataUsingEncoding(NSUTF8StringEncoding)
        default: return nil
        }
    }
    
    public func valueAsDate() -> NSDate? {
        switch (self._type) {
        case SQLITE_INTEGER, SQLITE_FLOAT: return NSDate(timeIntervalSince1970: self._value as Double)
        case SQLITE_TEXT:
            let df = NSDateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.dateFromString(self._value as String)
        case SQLITE_BLOB:
            let str = NSString(data: self._value as NSData, encoding: NSUTF8StringEncoding)
            let df = NSDateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.dateFromString(str)
        case SQLITE_NULL: return nil
        case SQLITE_DATE: return self._value as? NSDate
        default: return nil
        }
    }
    
    /**
    Types for SQLColumn values.
    
    Possible Value Types:
    
    - Integer
    - Double
    - String
    - Data
    - Date
    - Null
    */
    public enum Type: CInt, Printable {
        case Integer = 1
        case Double, Text, Data, Null, Date, Unknown
        public var description: String {
            switch self {
                case Integer: return "Integer"
                case Double: return "Double"
                case Data: return "Data"
                case Null: return "Null"
                case Date: return "Date"
                default: return "Text"
            }
        }
    }
    
    public var type: Type {
        get {
            return Type.fromRaw(_type)!
        }
    }
    
    public var description: String {
        return "<\(self.type.description): \(self.value)>"
    }
    
}

/**
Entry in a table. Contains an arbitrary number of SQLColumns accessed by key string.
*/
public class SQLRow: Printable {
    
    public var data = [String: SQLColumn]()
    
    public subscript(key: String) -> SQLColumn? {
        get {
            return data[key]
        }
        set (newVal) {
            data[key] = newVal
        }
    }
    
    public var description: String {
        var d = "<"
            for (key, val) in data {
                d += "(\(key)<\(val.type.description)>, \(val.value)), "
            }
            d = d.subStringTo(countElements(d)-2)
            d += ">"
            return d
    }
    
}

/**
Database object.
*/
public class SQLiteDB {
    
    private let DB_NAME = "data.db"
    private let BLANK_DB_NAME = "blank.db"
    private let QUEUE_LABEL = "SQLiteDB"
    private var db: COpaquePointer = nil
    private var queue: dispatch_queue_t
    
    private struct Static {
        static var instance: SQLiteDB? = nil
        static var token: dispatch_once_t = 0
    }
    
    /**
    Database singleton.
    */
    class func sharedInstance() -> SQLiteDB! {
        dispatch_once(&Static.token) {
            Static.instance = self()
        }
        return Static.instance!
    }
    
    private func pathForFile(name: String) -> String {
        let docDir: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let fileName = String.fromCString(name)
        let path = docDir.stringByAppendingPathComponent(fileName)
        return path!
    }
    
    public func didResetDatabase() -> (succeeded: Bool, error: NSError!) {
        let fm = NSFileManager.defaultManager()
        let path = pathForFile(DB_NAME)
        let blankDBName: String = String.fromCString(BLANK_DB_NAME)!
        let from = NSBundle.mainBundle().resourcePath.stringByAppendingPathComponent(blankDBName)
        var error: NSError?
        
        //        println(path)
        
        return (succeeded: fm.copyItemAtPath(from, toPath: path, error: &error), error: error)
    }
    
    required public init() {
        assert(Static.instance == nil, "Singleton already initialized")
        queue = dispatch_queue_create(QUEUE_LABEL, nil)
        
        let path = pathForFile(DB_NAME)
        let fm = NSFileManager.defaultManager()
        if !fm.fileExistsAtPath(path) {
            println("SQLiteDB - DB doesn't exist, attempting to create new one.")
            let resetDB = self.didResetDatabase()
            if !resetDB.succeeded {
                println("SQLiteDB - failed to copy writeable version of DB!")
                println("Error: \(resetDB.error.localizedDescription)")
                return
            }
            println("SQLiteDB - New database created.")
        }
        
        let cPath = path.cStringUsingEncoding(NSUTF8StringEncoding)
        let error = sqlite3_open(cPath!, &db)
        if error != SQLITE_OK {
            println("SQLiteDB - failed to open DB!")
            sqlite3_close(db)
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    /**
    Close the database and compress the file using VACUUM.
    */
    public func closeDatabase() {
        if db != nil {
            let ud = NSUserDefaults.standardUserDefaults()
            var launchCount = ud.integerForKey("LaunchCount")
            launchCount--
            println("SQLiteDB - Launch Count: \(launchCount)")
            
            var clean = false
            if launchCount < 0 {
                clean = true
                launchCount = 500
            }
            ud.setInteger(launchCount, forKey: "LaunchCount")
            ud.synchronize()
            
            if !clean {
                sqlite3_close(db)
                return
            }
            
            println("SQLiteDB - Optimize DB")
            let sql = "VACUUM; ANALYZE"
            if execute(sql) != SQLITE_OK {
                println("SQLiteDB - Error cleaning DB")
            }
            sqlite3_close(db)
        }
    }
    
    /**
    Remove the database file.
    */
    public func deleteDatabase() {
        let path = pathForFile(DB_NAME)
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(path) {
            var error: NSError?
            if !fm.removeItemAtPath(path, error: &error) {
                println("SQLiteDB - Error deleting DB: \(error!.localizedDescription)")
                return
            }
            println("SQLiteDB - DB deleted.")
        }
    }
    
    /**
    Execute a SQL command on the database.
    
    :param: sql SQL command.
    */
    public func execute(sql: String) -> CInt {
        var result: CInt = SQLITE_OK
        
        dispatch_sync(queue) {
            var cSql = sql.cStringUsingEncoding(NSUTF8StringEncoding)
            var stmt: COpaquePointer = nil
            result = sqlite3_prepare_v2(self.db, cSql!, -1, &stmt, nil)
            if result != SQLITE_OK {
                sqlite3_finalize(stmt)
                let msg = "SQLiteDB - Failed to prepare SQL: Error: \(self.lastSQLError())"
                println(msg)
                self.alert(msg: msg)
                return
            }
            
            result = sqlite3_step(stmt)
            if result != SQLITE_OK && result != SQLITE_DONE {
                sqlite3_finalize(stmt)
                let msg = "SQLiteDB - Failed to execute SQL: Error: \(self.lastSQLError())"
                println(msg)
                self.alert(msg: msg)
                return
            }
            
            if sql.uppercaseString.hasPrefix("INSERT ") {
                let rid = sqlite3_last_insert_rowid(self.db)
                result = CInt(rid)
            } else {
                result = 1
            }
            sqlite3_finalize(stmt)
        }
        
        return result
    }
    
    /**
    Execute a SQL query on the database, returning an array of SQLRows.
    
    :param: sql SQL command.
    */
    public func query(sql: String) -> [SQLRow] {
        var rows = [SQLRow]()
        
        dispatch_sync(queue) {
            var cSql = sql.cStringUsingEncoding(NSUTF8StringEncoding)
            var stmt: COpaquePointer = nil
            var result: CInt = 0
            
            result = sqlite3_prepare_v2(self.db, cSql!, -1, &stmt, nil)
            if result != SQLITE_OK {
                sqlite3_finalize(stmt)
                let msg = "SQLiteDB - Failed to prepare SQL: Error: \(self.lastSQLError())"
                println(msg)
                self.alert(msg: msg)
            }
            
            var fetchColumnInfo = true
            var columnCount: CInt = 0
            var columnNames = [String]()
            var columnTypes = [CInt]()
            result = sqlite3_step(stmt)
            while result == SQLITE_ROW {
                if fetchColumnInfo {
                    columnCount = sqlite3_column_count(stmt)
                    for index in 0..<columnCount {
                        let name = sqlite3_column_name(stmt, index)
                        columnNames.append(String.fromCString(name)!)
                        columnTypes.append(self.getColumnType(index, stmt: stmt))
                    }
                    fetchColumnInfo = false
                }
                var row = SQLRow()
                for index in 0..<columnCount {
                    let key = columnNames[Int(index)]
                    let type = columnTypes[Int(index)]
                    if let val: AnyObject = self.getColumnValue(index, type: type, stmt: stmt) {
                        let col = SQLColumn(value: val, type: type)
                        row[key] = col
                    }
                }
                rows.append(row)
                result = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        return rows
    }
    
    /**
    Escape a string for SQLite
    
    :param: str String to escape.
    */
    public func esc(str: String) -> String {
        let sql = Bridge.esc(str)
        return sql
    }
    
    private func lastInsertedRowID() -> Int64 {
        var lid: Int64 = 0
        dispatch_sync(queue) {
            lid = sqlite3_last_insert_rowid(self.db)
        }
        return lid
    }
    
    public func lastSQLError() -> String {
        let buf = sqlite3_errmsg(self.db)
        return NSString(CString: buf, encoding: NSUTF8StringEncoding)
    }
    
    private func alert(msg: String? = nil) {
        var txt = msg != nil ? msg! : lastSQLError()
        let alert = UIAlertView(title: "SQLiteDB", message: msg, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
    
    private func getColumnType(index: CInt, stmt: COpaquePointer) -> CInt {
        var type: CInt = 0
        
        let blobTypes = ["BINARY", "BLOB", "VARBINARY"]
        let charTypes = ["CHAR", "CHARACTER", "CLOB", "NATIONAL VARYING CHARACTER","NATIVE CHARACTER", "NCHAR", "NVARCHAR", "TEXT", "VARCHAR", "VARIANT", "VARYING CHARACTER"]
        let dateTypes = ["DATE", "DATETIME", "TIME", "TIMESTAMP"]
        let intTypes  = ["BIGINT", "BIT", "BOOL", "BOOLEAN", "INT", "INT2", "INT8", "INTEGER", "MEDIUMINT", "SMALLINT", "TINYINT"]
        let nullTypes = ["NULL"]
        let realTypes = ["DECIMAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT", "NUMERIC", "REAL"]
        
        let buf = sqlite3_column_decltype(stmt, index)
        if buf != nil {
            var tmp = String.fromCString(buf)!.uppercaseString
            let pos = tmp.positionOf("(")
            if pos > 9 {
                tmp = tmp.subStringTo(pos)
            }
            if contains(intTypes,  tmp) { return SQLITE_INTEGER }
            if contains(realTypes, tmp) { return SQLITE_FLOAT }
            if contains(charTypes, tmp) { return SQLITE_TEXT }
            if contains(blobTypes, tmp) { return SQLITE_BLOB }
            if contains(nullTypes, tmp) { return SQLITE_NULL }
            if contains(dateTypes, tmp) { return SQLITE_DATE }
            return SQLITE_TEXT
        } else {
            type = sqlite3_column_type(stmt, index)
        }
        return type
    }
    
    private func getColumnValue(index: CInt, type: CInt, stmt: COpaquePointer) -> AnyObject? {
        switch type {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int(stmt, index))
        case SQLITE_FLOAT:
            return Double(sqlite3_column_double(stmt, index))
        case SQLITE_BLOB:
            let data = sqlite3_column_blob(stmt, index)
            let size = sqlite3_column_bytes(stmt, index)
            return NSData(bytes: data, length: Int(size))
        case SQLITE_NULL:
            return nil
        case SQLITE_DATE:
            let txt = UnsafePointer<Int8>(sqlite3_column_text(stmt, index))
            if txt != nil {
                let buf = NSString(CString: txt, encoding: NSUTF8StringEncoding)
                let set = NSCharacterSet(charactersInString: "-:")
                let range = buf.rangeOfCharacterFromSet(set)
                if range.location != NSNotFound {
                    var time: tm = tm(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0, tm_wday: 0, tm_yday: 0, tm_isdst: 0, tm_gmtoff: 0, tm_zone: nil)
                    strptime(txt, "%Y-%m-%d %H:%M:%S", &time)
                    time.tm_isdst = -1
                    let diff = NSTimeZone.localTimeZone().secondsFromGMT
                    let t = mktime(&time) + diff
                    let ti = NSTimeInterval(t)
                    let val = NSDate(timeIntervalSince1970: ti)
                    return val
                }
            }
            let val = sqlite3_column_double(stmt, index)
            let dt = NSDate(timeIntervalSince1970: val)
            return dt
        default:
            // text
            let buf = UnsafePointer<Int8>(sqlite3_column_text(stmt, index))
            let val = String.fromCString(buf)
            return val
        }
        //        return nil
    }
    
}

public extension String {
    
    /**
    The position of a substring in a string.
    
    Returns -1 if the string does not contain the substring.
    
    :param: sub Substring to search for.
    */
    public func positionOf(sub: String) -> Int {
        var pos = -1
        
        if let range = self.rangeOfString(sub, options: nil, range: nil, locale: nil) {
            if !range.isEmpty {
                pos = distance(self.startIndex, range.startIndex)
            }
        }
        
        return pos
    }
    
    public func subStringFrom(pos: Int) -> String {
        var substr = ""
        let start = advance(self.startIndex, pos)
        let end = self.endIndex
        let range = start..<end
        substr = self[range]
        return substr
    }
    
    public func subStringTo(pos: Int) -> String {
        var substr = ""
        let end = advance(self.startIndex, pos-1)
        let range = self.startIndex...end
        substr = self[range]
        return substr
    }
    
}