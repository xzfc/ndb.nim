# How To Use NDB

The `ndb` library provides a general means of using SQL relational databases in Nim. Specifically, it supports:

* [SQLite](https://sqlite.org/index.html)
* [PostgreSQL](https://www.postgresql.org/)
* [MySQL](https://www.oracle.com/mysql/) / [MariaDB](https://mariadb.org/)

This document will take through a tour of using `ndb` and it's features. This document assumes you already understand the SQL language. If you are not familiar with SQL, I recommend visiting [this free CodeAcademy course](https://www.codecademy.com/learn/learn-sql) or searching for the many other resources online for learning SQL first.

## CONNECTING

When writing your nim program, you will want to first import the specific sub-library for your database.

For SQLite:

```nim
import ndb / sqlite
```

For PostgreSQL:

```nim
import ndb / postgresql
```

For MySQL or MariaDB:

```nim
import ndb / mariadb
```

The remaining examples in this document assume you are working SQLite, but the other database types should behave mostly the same.

Connect to the database using the `open` function and assign the result to a variable to hold the connection. And, later close it using the 'close' function.

```nim
import ndb / sqlite

let db = open("example.db", "", "", "")

# Add the database commands here.

db.close()
```

**EXTRA:** [Behind the Scenes](How-To-Use-NDB-behind-the-scenes.md)

**EXTRA:** [Connecting to Multiple Databases](How-To-Use-NDB-connecting-to-multiple-databases.md)

## MAKING TABLES

There are no specific functions for making new tables in `ndb`, instead you will simply rely on sending direct SQL statements to do it. That is done using the `exec` function.

This function, `exec` is fairly powerful and can also do parameter substitution. We will see more of that the CREATING RECORDS section below.

An example of making a new table:

```nim
import ndb / sqlite
let db = open("example.db", "", "", "")

let creation_query = """
    CREATE TABLE myGarden (
        id INTEGER PRIMARY KEY,
        name STRING NOT NULL,
        qty INTEGER,
        price FLOAT,
    )
"""
db.exec(creation_query)

db.close()
```

## CREATING RECORDS

You can, of course, simply create new records in a table by issueing a `exec` query to do so:

```nim
db.exec("""
    INSERT INTO MyGarden (id, name, qty, price) VALUES (1, "carrot", 20, 0.33)
""")
db.exec("""
    INSERT INTO MyGarden (id, name, qty, price) VALUES (2, "squash", 32, 0.5)
""")
```

Or you can use `exec`'s parameter substitution:

```nim
db.exec("""
    INSERT INTO MyGarden (id, name, qty, price) VALUES (?, ?, ?, ?)
""", 3, "cucumber", 22, 1632.2)
```

But `ndb` also supports a special function called `tryInsertID` which not only inserts the row but also create a new unique number for a matching `id` column and returns the value of that new id (`int64`).

```nim
var new_id = db.insertID("""
    INSERT INTO MyGarden (name, qty, price) VALUES (?, ?, ?)
""", "green bean", 100, 0.92)
```

If an error is found during the insertion, the returned number is -1. If you are wanting to do your own error catching, then use the alternate `insertID` function. See [CATCHING ERRORS] .

**EXTRA:** [Understanding Types](How-To-Use-NDB-understanding-types.md)

## READING RECORDS

The primary means of getting records from the database is the `rows` function. Simply pass a SQL statement to the function, the query is made and an *iterator* to a sequence of records is returned. Essentially, the iterator is for a `seq[Row]`, where a `Row` is a `seq[DbValue]`. And a `DbValue` is an object that can hold multiple types of values, including strings, integers, nulls, etc.

So, to illustrate this with an example:

```nim
import ndb / sqlite
let db = open("example.db", "", "", "")

var cheap_vegs = db.rows("SELECT name, qty FROM MyGarden WHERE price < 1.00 ORDER BY name")
```

We are going to assume that there are three matching records. So, the variable `cheap_vegs` is now pointing to the first record as an iterator. For example, it might be:

|ptr  |name       |qty
|-----|-----------|---
|*    |carrot     | 20
|     |green bean |100
|     |squash     | 32

Now the variable `cheap_vegs` can be called to get a record.

```nim
var first_veg = cheap_vegs()
echo $first_veg[0] & ": " & $first_veg[1]  # prints "carrot: 20"
```

Notice that the record `first_veg` is a sequence, so the columns are referenced by number.
And, now the `cheap_vegs` iterator has moved to the next row.

|ptr  |name       |qty
|-----|-----------|---
|     |carrot     | 20
|*    |green bean |100
|     |squash     | 32

Since `first_veg` contains the record, we can also access the column's data based on what type of column it is. In this case, the first column is a string, so use `.s`. The second column is an integer, so use `.i`.

```nim
if first_veg[1].isNotNull:
  echo first_veg[0].s & ": " & $(first_veg[1].i * 100) # prints "carrot: 2000"
```

And since 'cheap_vegs' it is an iterator, we can also use it in a `for` loop:

```nim
for v in cheap_vegs:
  echo $v[0] & ": " & $v[1]
```

which prints the remaining items

```
green bean: 100
squash: 32
```

#### READING RECORDS: HANDLING NO RESULTS

If the query has no rows to return (no matches found), then the iterator points to no results. Simply check the iterator for the `finished` condition:

```nim
import ndb / sqlite
let db = open("example.db", "", "", "")

var super_expensive = db.rows(sql"SELECT name, qty FROM MyGarden WHERE price > 1000.00")

if finished(super_expensive):
    echo "nothing super-expensive found"
else:
    echo "1 or more super-expensive found"
```

#### READING RECORDS: GETTING FEWER (OR ONE)

You can set a limit on the results by either passing that limit in the SQL. Or you can add an optional parameter to your `rows` call.

```nim
import ndb / sqlite
let db = open("example.db", "", "", "")

var some = db.rows("SELECT name, qty FROM MyGarden LIMIT 2")
# or you can do:
some = db.rows("SELECT name, qty FROM MyGarden", 2)
```

If you are only wanting _one_ result, you can also use the `getRow` function to get the *first* row found. The function returns an `Option[Row]`

```nim
import ndb / sqlite

let db = open("example.db", "", "", "")

var cucumber = db.rows("SELECT qty FROM MyGarden WHERE name='cucumber")

if cucumber.isNone:
  echo "No cucumber found."
else:
  echo "cucumber: " & $cucumber.get()  # prints "cucumber: 22"

db.close()
```

**EXTRA:** [Understanding Types](How-To-Use-NDB-understanding-types.md)

## UPDATING RECORDS

Updates are best done using the `execAffectedRows` function. You pass the SQL UPDATE query in a manner similar to the exec function, but this function returns the number of rows that it affected.

```nim
var count = db.execAffectedRows("""
    UPDATE MyGarden SET price = 0.90 WHERE name=?
""", "green bean")

echo $count  # prints "1"
```

If no rows are updates, you will get a zero (0) returned.

## DELETING RECORDS

Deletions are best done using the `execAffectedRows` function. You pass the SQL DELETE query in a manner similar to the exec function, but this function returns the number of rows that it affected.

```nim
var count = db.execAffectedRows("""
    DELETE FROM MyGarden WHERE name=?
""", "carrot")

echo $count  # prints "1"
```

If no rows are deleted, you would get a zero (0) returned.

## CATCHING ERRORS

TODO

## [NOTES ABOUT THIS DOC]

This notes section will go away on first release. Some stuff jotted down.

This doc is written with the presumption that the notes marked here are implemented rather than how things work right now.

* Adding a `isNull` function. (and possibly `isNotNull`)
* We deprecate the `sql` string distinction as it seems to do nothing more than add complexity. However, for legacy purposes, the sql type is not removed.
* db_common is made part of the library in preparation of movement of `ndb` to the standard library. As such:
  - embrace the "kinds" from db_common (do the migration)
  - All of the variants will uniquely interpret all of the types. If a type is specifically not supported, a compile-time error (rather than run-time) is generated. However, I don't think this will ever be needed. If nothing else, a type can be a string conversion.
  - nim can't do decimals. As such, make sure that `DECIMAL` columns can be exported as strings to avoid the faulty `float` conversion.
* Add ref links to each introduction to a new function or type.

