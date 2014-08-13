//
//  Person.swift
//  SQLiteDB Example
//
//  Created by Kai Wells on 8/11/14.
//  Copyright (c) 2014 Kai Wells. All rights reserved.
//

import UIKit

public class Person: Model {
   
    override public func className() -> String {
        return "Person"
    }
    
    public var id: String = NSUUID.UUID().UUIDString
    public var name: String = ""
    public var age: Int = 0
    public var dateCreated: NSDate = NSDate()
    public var dateModified: NSDate = NSDate()
    
    override init() {
        super.init()
        shouldUpdate()
    }
    
    override public func shouldUpdate() -> Bool {
        dateModified = NSDate()
        self._properties = [id, name, age, dateCreated, dateModified]
        return true
    }
    
    override public func shouldInsert() -> Bool {
        shouldUpdate()
        return true
    }
    
    override public func shouldDelete() -> Bool {
        shouldUpdate()
        return true
    }
    
    override public var description: String {
        return "<\(self.name) age \(self.age), created \(self.dateCreated)>"
    }
    
}

public class People: Model {
    
    override public func className() -> String {
        return "People"
    }
    
    public var id: Int = 0
    public var people: NSArray = NSArray()
    public var dateModified: NSDate = NSDate()
    
    override init() {
        super.init()
        shouldUpdate()
    }
    
    override public func shouldUpdate() -> Bool {
        dateModified = NSDate()
        self._properties = [id, people, dateModified]
        return true
    }
    
    public func add(person: Person) {
        var temp = self.people.mutableCopy() as NSMutableArray
        temp.insertObject(person.id, atIndex: 0)
        self.people = temp.copy() as NSArray
        shouldUpdate()
    }

    public func remove(person: Person) {
        var temp = self.people.mutableCopy() as NSMutableArray
        temp.removeObject(person.id)
        self.people = temp.copy() as NSArray
        shouldUpdate()
    }
    
}