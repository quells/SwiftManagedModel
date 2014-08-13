//
//  MasterViewController.swift
//  Example
//
//  Created by Kai Wells on 8/12/14.
//  Copyright (c) 2014 Kai Wells. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {
    
    var detailViewController: DetailViewController? = nil
    // DatabaseController can be a class constant
    let dbController = ExampleDatabaseController()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        self.navigationItem.rightBarButtonItem = addButton
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = controllers[controllers.count-1].topViewController as? DetailViewController
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func insertNewObject(sender: AnyObject) {
        addPerson()
        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            let indexPath = self.tableView.indexPathForSelectedRow()
            let controller = (segue.destinationViewController as UINavigationController).topViewController as DetailViewController
            
            let people = (dbController.firstInstanceOf(People()) as People).people
            let personID = people.objectAtIndex(indexPath.row) as String
            let person: Person? = dbController.firstInstanceOf(Person(), whereProperty: "id", equals: personID) as? Person
            
            controller.detailItem = person
            controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem()
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dbController.countInstancesOf(Person())
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
        
        let people = (dbController.firstInstanceOf(People()) as People).people
        let personID = people.objectAtIndex(indexPath.row) as String
        let person: Person? = dbController.firstInstanceOf(Person(), whereProperty: Person().primaryKey(), equals: personID) as? Person
        if let personName = person?.name {
            cell.textLabel.text = personName
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let people = dbController.firstInstanceOf(People()) as People
            let peopleList = people.people
            let personID = peopleList.objectAtIndex(indexPath.row) as String
            let person = dbController.firstInstanceOf(Person(), whereProperty: Person().primaryKey(), equals: personID) as Person
            dbController.removeModelObject(person)
            people.remove(person)
            dbController.update(people, onRowsWhere: People().primaryKey(), equals: people.primaryKeyValue())
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    
}

/**
Example implementation of adding a managed Model object to both a database and an ordered list.
*/
public func addPerson() {
    let dbController = ExampleDatabaseController()
    
    if dbController.countInstancesOf(People()) < 1 {
        let people = People()
        dbController.insertModelObject(people)
    }
    
    let p = Person()
    p.name = randomName()
    p.age = Int(arc4random_uniform(99))
    
    if let people: People = dbController.firstInstanceOf(People()) as? People {
        people.add(p)
        dbController.insertModelObject(p)
        dbController.update(people, onRowsWhere: People().primaryKey(), equals: people.primaryKeyValue())
    } else {
        println("😿")
    }
}