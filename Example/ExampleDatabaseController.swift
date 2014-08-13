//
//  ExampleDatabaseController.swift
//  SQLiteDB Example
//
//  Created by Kai Wells on 8/11/14.
//  Copyright (c) 2014 Kai Wells. All rights reserved.
//

import Foundation

public class ExampleDatabaseController: DatabaseController {

    public func schema1() {
        if self.schemaVersion() < 1 {
            println("SQLiteDB - Initiating Schema v1")
            db.execute(People().createCommand())
            db.execute(Person().createCommand())
            db.execute(Person().indexCommand("dateCreated"))
            db.execute(Person().uniqueCommand("id"))
            self.incrementSchemaVersion()
        }
    }
    
}
