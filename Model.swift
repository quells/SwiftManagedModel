//
//  Model.swift
//  SQLiteTest
//
//  Created by Kai Wells on 8/10/14.
//  Copyright (c) 2014 Kai Wells. All rights reserved.
//

import Foundation

public class Model: NSObject, Printable {
    
    // MARK: - Properties
    
    /**
    Name used as table name in autogenerated SQL commands.
    Does not necessarily have to correspond to actual class name.
    Should be overridden by subclasses.
    
    `Schema` is a reserved table name used by `DatabaseController` to assist in schema migration.
    
    :returns: Class name as String.
    */
    public func className() -> String {
        return "Model"
    }
    
    /**
    Used to pass around property names and types.
    Should not have to be created manually.
    
    :param: name The name of the property.
    :param: type The type of the property.
    */
    internal struct Property: Printable {
        var Name: String
        var Type: String
        
        init(name: String, type: String) {
            self.Name = name
            self.Type = type
        }
        
        var description: String {
            return "<\(self.Name): \(self.Type)>"
        }
    }
    
    /**
    Load an instance with data from a SQLiteDB, modifying `self` to match the data in `row`.
    
    :param: row The row from which to load data. Should come from table called `className()`.
    */
    public func copyFrom(row: SQLRow) {
        for (i, p) in enumerate(self.properties) {
            if let col = row.data[p.Name] {
                if p.Type == "NSNumber" {
                    self.setValue(col.value, forKey: p.Name)
                } else if p.Type == "NSString" {
                    self.setValue(col.valueAsString(), forKey: p.Name)
                } else if p.Type == "NSDate" {
                    self.setValue(col.valueAsDate(), forKey: p.Name)
                } else if p.Type == "NSArray" {
                    self.setValue(self.deserializedArrayFromDatabaseValue(col.valueAsString()), forKey: p.Name)
                } else if p.Type == "NSDictionary" {
                    println("Managed Model - Not supported yet.")
                }
            }
        }
    }
    
    /**
    Source of properties used to autogenerate SQL commands.
    
    All properties of a subclass should be contained in this array.
    Values should be entered in the order in which they appear in the subclass declaration.
    Properties that will not be saved to the database should be implemented as functions (eg. `className()`).
    
    Should be overwritten in subclasses' `shouldUpdate()` to maintain fresh values in `properties`.
    
    The first value in the array will be used as the primary key.
    
    Valid managed property types:
    
    - Int, Double
    - String, NSString
    - NSArray
    - NSDictionary (eventually)
    - NSDate
    */
    internal var _properties: [AnyObject] = []
    
    /**
    Autogenerated list of `Property`s based on `_properties`.
    */
    internal var properties: [Property] {
        // Undocumented Mirror API Usage - Likely to Break
        // https://gist.github.com/peebsjs/9288f79322ed3119ece4
        var _propertyNames: [String] = []
            let mirror = reflect(self)
            for i in 0 ..< mirror.count {
                let (childKey, childMirror) = mirror[i]
                if childKey != "super" { _propertyNames.append(childKey) }
            }
            
            var _propertyTypes: [String] = []
            for o in self._properties {
                _propertyTypes.append(NSStringFromClass(o.classForKeyedArchiver))
            }
            
            var _returnedProperties: [Property] = []
            for i in 0 ..< _propertyTypes.count {
                _returnedProperties.append(Property(name: _propertyNames[i], type: _propertyTypes[i]))
            }
            return _returnedProperties
    }
    
    /**
    :returns: Primary key for SQLiteDB (the first entry in `properties`) or an empty string.
    */
    public func primaryKey() -> String {
        let props = self.properties
        if props.count < 1 {
            return ""
        }
        return props[0].Name
    }
    
    /**
    :returns: Value for the primary key in SQLiteDB (the first entry in `_properties`) or nil.
    */
    public func primaryKeyValue() -> AnyObject! {
        if self._properties.count < 1 {
            return nil
        }
        return self._properties[0]
    }
    
    // MARK: - SQL Commands
    
    /**
    :returns: Autogenerated SQL command to create tables based on `className()` and `_properties`.
    */
    public func createCommand() -> String {
        var command = "CREATE TABLE \(className()) ("
        let props = self.properties
        for (i, p) in enumerate(props) {
            command += "\(p.Name) "
            if p.Type == "NSNumber" {
                command += "INTEGER"
            } else if p.Type == "NSNumber" {
                command += "FLOAT"
            } else if p.Type == "NSString" {
                command += "TEXT"
            } else if p.Type == "NSData" {
                command += "TEXT"
            }else if p.Type == "NSArray" {
                command += "TEXT"
            } else if p.Type == "NSDate" {
                command += "FLOAT"
            } else {
                println("What? \(p.Type)")
            }
            if i == 0 { command += " PRIMARY KEY" }
            command += " NOT NULL"
            command += i == props.count-1 ? "" : ", "
        }
        command += ");"
        return command
    }
    
    /**
    :returns: Autogenerated SQL command to insert rows based on `className()` and `_properties`.
    */
    public func insertCommand() -> String {
        var command = "INSERT INTO \(self.className()) ("
        let props = self.properties
        for (i, p) in enumerate(props) {
            command += p.Name
            command += i == props.count-1 ? "" : ", "
        }
        command += ") VALUES ("
        for (i, p) in enumerate(self._properties) {
            command += sanitizedDBRepresentationOfValue(p)
            command += i == props.count-1 ? "" : ", "
        }
        command += ");"
        return command
    }
    
    /**
    :returns: Autogenerated SQL command to delete rows based on `className()` and `_properties`.
    */
    public func deleteCommand() -> String {
        let primaryKeyName: String = self.primaryKey()
        if primaryKeyName == "" {
            return ""
        }
        let primaryKeyValue: AnyObject = self._properties[0]
        return "DELETE FROM \(self.className()) WHERE \(primaryKeyName) = \(sanitizedDBRepresentationOfValue(primaryKeyValue));"
    }
    
    /**
    :returns: Autogenerated SQL command to index table based on `className()` and `_properties`.
    
    :param: propertyName Property to be indexed. Should match a name in `_properties`.
    */
    public func indexCommand(propertyName: String) -> String {
        return "CREATE INDEX IF NOT EXISTS \(propertyName) ON \(self.className()) (\(propertyName));"
    }
    
    /**
    :returns: Autogenerated SQL command to create a unique index based on `className()` and `_properties`.
    
    :param: propertyName Property to be indexed. Should match a name in `_properties`.
    */
    public func uniqueCommand(propertyName: String) -> String {
        return "CREATE UNIQUE INDEX IF NOT EXISTS \(propertyName) ON \(self.className()) (\(propertyName));"
    }
    
    /**
    :returns: Autogenerated SQL command to update rows based on `className()` and `_properties`.
    
    :param: onRowsWhere Property name to match.
    :param: equals Property value to match.
    */
    public func updateCommmand(onRowsWhere: String, equals: AnyObject) -> String {
        var command = "UPDATE \(self.className()) SET "
        let props = self.properties
        for i in 0..<props.count {
            let propertyName = props[i].Name
            let propertyValue: AnyObject = _properties[i]
            command += "\(propertyName) = \(sanitizedDBRepresentationOfValue(propertyValue))"
            command += i == props.count-1 ? " " : ", "
        }
        command += "WHERE \(onRowsWhere) = \(sanitizedDBRepresentationOfValue(equals));"
        return command
    }
    
    /**
    :returns: Autogenerated SQL command to select rows based on `className()`.
    
    :param: rowsWhere Property name to match.
    :param: equals Property value to match.
    */
    public func selectCommand(rowsWhere: String, equals: AnyObject) -> String {
        return "SELECT * FROM \(self.className()) WHERE \(rowsWhere) = \(sanitizedDBRepresentationOfValue(equals))"
    }
    
    // MARK: - Utilities
    
    /**
    Normalizes values for storage in a SQLiteDB.
    
    :param: value Object to normalize of type Int, Double, String, NSData, NSArray, NSDictionary, or NSDate.
    
    :returns: Normalized string.
    */
    private func sanitizedDBRepresentationOfValue(value: AnyObject) -> String {
        if let int = value as? Int {
            return "\(int)"
        } else if let double = value as? Double {
            return "\(double)"
        } else if let text = value as? String {
            return "'\(text)'"
        } else if let blob = value as? NSData {
            println("Managed Model - Not supported yet.")
            return ""
//            return "'\(blob)'"
        } else if let array = value as? NSArray {
            return "'\(serializedDatabaseRepresentationOfValue(array))'"
        } else if let dictionary = value as? NSDictionary {
            return "'\(serializedDatabaseRepresentationOfValue(dictionary))'"
        } else if let date = value as? NSDate {
            return "\(serializedDatabaseRepresentationOfValue(date))"
        } else {
            return ""
        }
    }
    
    /**
    Normalizes NSArray, NSDictionary, NSURL, and NSDate for storage in a SQLiteDB.
    
    :param: value Object to serialize of type NSArray, NSDictionary (eventually), NSURL, or NSDate.
    
    :returns: Serialized object (String or Double).

    */
    private func serializedDatabaseRepresentationOfValue(value: AnyObject) -> AnyObject! {
        // Using JSON text representations for NSArray and NSDictionary instead of NSData and BLOB.
        // Using Double representations for NSDate instead of TIMESTAMP or DATETIME.
        if value.isKindOfClass(NSArray.self) || value.isKindOfClass(NSDictionary.self) {
            var error: NSError?
            var data: NSData = NSJSONSerialization.dataWithJSONObject(value, options: .PrettyPrinted, error: &error)
            if error != nil { NSException(name: NSInvalidArgumentException, reason: "Cannot serialize object", userInfo: nil).raise() }
            var json = NSString(data: data, encoding: NSUTF8StringEncoding)
            return json
        } else if value.isKindOfClass(NSDictionary.classForKeyedArchiver()) {
            println("Managed Model - Not supported yet.")
            return nil
        } else if value.isKindOfClass(NSURL.classForKeyedArchiver()) {
            return value.absoluteString
        } else if value.isKindOfClass(NSDate.classForKeyedArchiver()) {
            return NSNumber(double: value.timeIntervalSince1970)
        }
        return nil
    }
    
    /**
    Converts from a normalized String stored by a SQLiteDB to an NSArray.
    
    :param: value Normalized string containing an NSArray.
    
    :returns: NSArray with contents of `value`.
    */
    internal func deserializedArrayFromDatabaseValue(value: String) -> NSArray! {
        if let data = value.dataUsingEncoding(NSUTF8StringEncoding) {
            if let array = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: nil) as? NSArray {
                return array
            }
        }
        return nil
    }
    
    // TODO: deserializedDictionaryFromDatabaseValue(value: String) -> NSDictionary!
    
    /**
    Stub that should be overridden by subclass. It should probably call `shouldUpdate` to update `_properties`.
    
    `DatabaseController` checks this value before executing insert commands.
    */
    public func shouldInsert() -> Bool { return true }
    
    /**
    Stub that should be overridden by subclass. It should set `_properties` to an array of its properties.
    
    `DatabaseController` checks this value before executing update commands.
    */
    public func shouldUpdate() -> Bool { return true }
    
    /**
    Stub that should be overridden by subclass. It should probably call `shouldUpdate` to update `_properties`.
    
    `DatabaseController` checks this value before executing delete commands.
    */
    public func shouldDelete() -> Bool { return true }
    
// Copied from FCModel - haven't found a use for these yet.
//    public func didInsert() {}
//    public func didUpdate() {}
//    public func didDelete() {}
//    public func saveWasRefused() {}
//    public func saveDidFail() {}
    
    override public var description: String {
        return "<\(self.className())>"
    }
    
}