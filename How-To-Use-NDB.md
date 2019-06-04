# How To Use NDB

The `ndb` library provides a general means of using SQL relational databases in Nim. Specifically, it supports:

* [SQLite](https://sqlite.org/index.html)
* [PostgreSQL](https://www.postgresql.org/) (in progress)
* [MySQL](https://www.oracle.com/mysql/) / [MariaDB](https://mariadb.org/) (in the future)

This document will take through a tour of using `ndb` and it's features. This document assumes you already understand the SQL language. If you are not familiar with SQL, I recommend visiting [this free CodeAcademy course](https://www.codecademy.com/learn/learn-sql) or searching for the many other resources online for learning SQL first.

## GETTING STARTED

To begin, you will need to get `ndb` library.

Right now, `ndb` can be found at the Nimble resource center. Details at [https://nimble.directory/pkg/ndb](https://nimble.directory/pkg/ndb). Install it for your computer:

```bash
~$ nimble refresh
Downloading Official package list
    Success Package list downloaded.
~$ nimble install ndb
Downloading https://github.com/xzfc/ndb.nim using git
  Verifying dependencies for ndb@0.19.4
 Installing ndb@0.19.4
   Success: ndb installed successfully.
~$
```

Then, when writing your nim program, you will want to import the library for the specific database type you are wanting to connect to.

For SQLite:

```nim
import ndb / sqlite
```

For PostgreSQL (not working yet):

```nim
import ndb / postgresql
```

For MySQL or MariaDB (not working yet):

```nim
import ndb / mariadb
```

The remaining examples in this document assume you are working SQLite, but the other database types should behave mostly the same.

Then connect to the database using the `open` function, assigned the result to a variable to hold the connection. And later close it when finished using the 'close' function.

```nim
import ndb / sqlite

let db = open("example.db", "", "", "")

# Add the database commands here.

db.close()
```

#### SIDEBAR: BEHIND THE SCENES

> This library does not access the databases directly. Instead, they wrap some common C libraries already written and officially supported for the database. Links:
> 
> * SQLite: [x]()
> * PostgreSQL: [x]()
> * MySQL: [x]()

#### SIDEBAR: CONNECTING TO MULTIPLE DATABASES

> It is possible to connect to multiple databases, even databases of different kinds. Simply import both library types with aliases to prevent name collision. You can also directly import a "dbtypes" library to use the shared database types between libraries.
> 
> For example:
> 
```nim
import ndb / dbtypes
import ndb / sqlite as s
import ndb / postgresql as p

let sdb = s.open("example.db", "", "", "")
let pdb = p.open("localhost", "MyDB", "sammy", "sammy")

# [TODO] more here

sdb.close()
pdb.close()
```

## MAKING TABLES

There are not specific functions for creating tables in `ndb`, instead you will simply rely on sending direct SQL statements to do it. That is done using the `exec` function. The string containing the statements is prefixed with `sql` to make such strings distinct.

This function, `exec` is fairly powerful and can also do parameter substitution. We will see more of that the READING RECORDS section below.

An example:

```
import ndb / sqlite
let db = open("example.db", "", "", "")

let creation_query = sql"""
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

## READING RECORDS

The primary means of getting records from the database is the `rows` function. Simply pass a SQL statement to the function, the query is made and an *iterator* to a sequence of records is returned. Essentially, the iterator is for a `seq[Row]`, where a `Row` is a `seq[DbValue]`. And a `DbValue` is an object that can hold multiple types of values, including strings, integers, nulls, etc.

So, to illustrate this with an example:

```nim
import ndb / sqlite
let db = open("example.db", "", "", "")

var cheap_vegs = db.rows(sql"SELECT name, qty FROM MyGarden WHERE price < 1.00 ORDER BY name")
```

We are going to assume that there are three matching records. So, the variable `cheap_vegs` is now pointing to the first record as an iterator. For example, it might be:

ptr  |name       |qty
-----|-----------|---
here |carrot     | 20
.    |green bean |100
.    |squash     | 32

The variable `cheap_vegs` can be used to get a record.

```nim
var first_veg = cheap_vegs
echo $first_veg[0] & ": " & $first_veg[1]  # prints "carrot: 20"
```

Notice that the record `first_veg` is a sequence, so the columns are referenced by number.
And, now the `cheap_vegs` iterator has moved to the next row.

ptr  |name       |qty
-----|-----------|---
.    |carrot     | 20
here |green bean |100
.    |squash     | 32

Since `first_veg` contains the record, we can also access the column's data based on what type of column it is. In this case, the first column is a string, so use `.s`. The second column is an integer, so use `.i`.

```nim
if first_veg[1].isNotNull:
  echo first_veg[0].s & ": " & $(first_veg[1].i * 100) # prints "carrot: 2000"
```

[NOTE: IMO we seriously need 'isNotNull' and 'isNull' functions.]

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

### HANDLING NO RESULTS

If the query has no rows to return (no matches found), then the iterator points to no results. Simply check the iterator for the `finished` condition:

```
import ndb / sqlite
let db = open("example.db", "", "", "")

var super_expensive = db.rows(sql"SELECT name, qty FROM MyGarden WHERE price > 1000.00")

if finished(super_expensive):
    echo "nothing super-expensive found"
else:
    echo "1 or more super-expensive found"
```

### GETTING FEWER (OR ONE)

You can set a limit on the results by either passing that limit in the SQL. Or you can add an optional parameter to your `rows` call.

```
import ndb / sqlite
let db = open("example.db", "", "", "")

var some = db.rows(sql"SELECT name, qty FROM MyGarden LIMIT 2")
# or you can do:
some = db.rows(sql"SELECT name, qty FROM MyGarden", 2)
```
If you are only wanting ONE result, you can also use the `getRow` function to get the *first* row found. The function returns an `Option[Row]`

```
import ndb / sqlite

let db = open("example.db", "", "", "")

var cucumber = db.rows(sql"SELECT qty FROM MyGarden WHERE name='cucumber")

if cucumber.isNone:
  echo "No cucumber found."
else:
  echo "cucumber: " & $cucumber.get()  # prints "cucumber: 22"

db.close()
```

### UNDERSTANDING TYPES

[TODO]

## CREATING RECORDS

You can, of course, simply create new records in a table by issueing a `exec` query to do so:

 ```nim
db.exec(sql"""
    INSERT INTO MyGarden (id, name, qty, price) VALUES (1, "carrot", 20, 0.33)
""")
```

Or you can use `exec`'s parameter substitution:

```nim
db.exec(sql"""
    INSERT INTO MyGarden (id, name, qty, price) VALUES (?, ?, ?, ?)
""", 2, "cucumber", 22, 1632.2)
```

But `ndb` also supports a special function called `tryInsertID` which not only inserts the row but also create a new unique number for a matching `id` column and returns the value of that new id (`int64`).

```nim
var new_id = db.insertID(sql"""
    INSERT INTO MyGarden (name, qty, price) VALUES (?, ?, ?)
""", "green bean", 100, 0.92)
```

If an error is found during the insertion, the returned number is -1. If you are wanting to do your own error catching, then use the alternate `insertID` function.

## UPDATING RECORDS

Updates are best done using the `execAffectedRows` function. You pass the SQL UPDATE query in a manner similar to the exec function, but this function returns the number of rows that it affected.

```nim
var count = db.execAffectedRows(sql"""
    UPDATE MyGarden SET price = 0.90 WHERE name=?
""", "green bean")

echo $count  # prints "1"
```

If no rows are updates, you will get a zero (0) returned.

## DELETING RECORDS

Deletions are best done using the `execAffectedRows` function. You pass the SQL DELETE query in a manner similar to the exec function, but this function returns the number of rows that it affected.

```nim
var count = db.execAffectedRows(sql"""
    DELETE FROM MyGarden WHERE name=?
""", "carrot")

echo $count  # prints "1"
```

If no rows are deleted, you would get a zero (0) returned.

## CATCHING ERRORS

[TODO]