Swift Managed Model
===================

An alternative to Core Data written in Swift.

By [Kai Wells](http://kaiwells.me). Released under the [MIT License](https://github.com/quells/SwiftManagedModel/blob/master/LICENSE) (at least `Model.swift` and `DataController.swift` are - SQLiteDB is under DWYWPL).

Inspired by [Marco Arment's FCModel](https://github.com/marcoarment/FCModel), but implemented in Swift and with most of the SQL hidden away / auto-generated. So not really like FCModel at all. But you can also run arbitrary SQL commands as you please!

It's built on [Fahim Farook's SQLiteDB](https://github.com/FahimF/SQLiteDB) with some modifications. Check it out if you're into that sort of thing.

### Goals

- Fairly small and fast.
- Concise public Swift API.
- Hide as much of the SQL as possible.
- Use [dark magic](https://gist.github.com/peebsjs/9288f79322ed3119ece4)* to auto-generate SQL commands.

*Or regular magic, if I missed something from a public API that does the same thing. Or if a public API comes out in a later version of Swift. Or jump over to Objective-C for that part, where such things are legal.

### Requirements

- Xcode 6 - Beta 5 (Swift is still in flux, so it's not guaranteed to work in any earlier or later builds. The *undocumented* mirroring API (and other things) may have breaking changes in Beta 6 and later.)
- Deployment on iOS 7 or above (for Swift compatibility) (OS X is not supported)
- [My Fork](https://github.com/quells/SQLiteDB) of SQLiteDB
- Linking your project with `sqlite3`

### Adding to Your Project

1. Add / copy all of the source files from SQLiteDB to your project.
2. Use the included `Bridging-Header.h` ("Objective-C Bridging Header" in your project's "Build Settings"), or link to it in your own.
3. Link the SQLite library (`libsqlite3.0.dylib`) to your project.
4. Add / copy `Model.swift` and `DatabaseController.swift` to your project.

### Documentation

Check out `Model.swift`, `DatabaseController.swift`, the example project, and the Usage section below.

"Quick Documentation" popovers (option-click on classes, functions, and variables) should work in Xcode 6 betas.

## Usage

See [here](https://github.com/FahimF/SQLiteDB) for SQLiteDB usage.

### Model

#### Subclass

`Model.swift` is fairly useless on its own; subclass it.

```swift
public class Person: Model {
	override public func className() -> String { return "Person" }
	
	public var id: Int = 0
	public var name: String = ""
	public var dateModified: NSDate = NSDate()
	
	override public func shouldUpdate() -> Bool {
		self._properties = [id, name, dateModified]
		return true
	}
}
```

#### Properties

Setting `self._properties` in `shouldUpdate()` is **the most important part here**. This array is used by the `Model` superclass to generate the SQL commands that make the whole thing work.

Overriding `shouldInsert()` and `shouldDelete()` to include a call to `shouldUpdate()` is a good idea, too. See `Person.swift` in the example project.

The variables in `Person` should all be in `self._properties` and in the same order in which they appear in the class declaration. They need to line up for the mirroring API to work its dark magic*. "Properties" that won't be saved in the SQLiteDB should be one-liner functions like `className()` so that they don't show up in the mirroring API.

*Maybe there's a way around it. I've thought about comparing values to reorder out-of-order properties, but that sounds slow for large objects.

#### Ordering

See `Person.swift` in the example project to see a basic implementation of an ordered list. Specifically, `People: Model` has a property `people` that is an NSArray to store the `id` of `Person` objects.

### DatabaseController

#### Subclass

You could probably get away with using `DatabaseController.swift` directly, but let's subclass it to make schema versioning cleaner.

```swift
public class PersonDatabaseController: DatabaseController {
	public func schema1() {
		if self.schemaVersion() < 1 {
			println("SQLiteDB - Initiating Schema v1")
			db.execute(Person().createCommand())
			db.execute(Person().uniqueCommand("id"))
			db.execute(Person().indexCommand("dateCreated"))
			self.incrementSchemaVersion()
		}
	}
	public func schema2() {
		if self.schemaVersion() < 2 {
			// Do migration
		}
	}
}
```

Aside: `db.execute()` sends the command string to the SQLiteDB and returns a `CInt`, but I haven't found the return value to be all that useful. Tends to always be `1`, regardless of SQL errors or successes. Your mileage may vary.

#### Initialize

Now all you have to do is call

```swift
let dbController = PersonDatabaseController()
dbController.schema1()
dbController.schema2()
// Schema 3, 4, … 100
```

and your database is ready to go. This can go in `AppDelegate.swift`.

It may be useful to call `dbController.newDatabase()` before the schema calls during development to simulate a fresh installation.

#### Use

To add an instance of `Person`:

```swift
let p = Person()
p.name = "Sally"
p.id = 42 // Or a more random number
dbController.insertModelObject(p)
```

To fetch instances of `Person`:

```swift
let firstPerson: Person! = dbController.firstInstanceOf(Person())
// If none exist, returns nil

let sally: Person! = dbController.firstInstanceOf(Person(), whereProperty: "name", equals: "Sally")
// If not found, returns nil
// Usually you would look up an instance by its `primaryKey()` property, but you don't have to.

let everybody: [Person] = dbController.allInstancesOf(Person())
// Can be empty array, but contents shouldn't be nil
```

To update an existing `Person`:

```
sally.name = "Billy"
dbController.update(sally, onRowsWhere: Person().primaryKey(), equals: sally.primaryKeyValue())
```

Note that the `update()` function uses the instance of `Person` that is being updated, while `firstInstanceOf()` and `allInstancesOf()` used a new class instance. The `update()` function pulls properties from the instance it is given to generate the SQL command, but `firstInstanceOf()` and `allInstancesOf()` only pull the `className()` so they can use any instance.

### Arbitrary SQL

If you're into that sort of thing:

```swift
dbController.db.execute("VACUUM; ANALYZE;")
```

## Contributions

Contributions are welcome! This is pretty rough.

## License

`Model.swift` and `DataController.swift` are released under an [MIT License](https://github.com/quells/SwiftManagedModel/blob/master/LICENSE). SQLiteDB and associated files are released under a DWYWPL by [Fahim Farook](https://github.com/FahimF/SQLiteDB).

## Known Issues

- Very slow for more than a handful of objects. The current method for adding objects scales linearly up to 1000 inserts, which took ~80 seconds on an iPhone 5S. This can probably be greatly improved by coalescing database writes.
- NSData blobs are not handled.
- NSDictionary is not handled.

## Version History

### 0.1

- Initial commit.
