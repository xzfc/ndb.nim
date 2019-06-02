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

Technical references:

database   | function
---------- | --------
SQLite     | [open](https://xzfc.github.io/ndb.nim/v0.19.4/sqlite.html#open%2Cstring%2Cstring%2Cstring%2Cstring)
SQLite     | [close](https://xzfc.github.io/ndb.nim/v0.19.4/sqlite.html#close%2CDbConn)
PostgreSQL | open
PostgreSQL | open
MariaDB    | open
MariaDB    | close

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

var cheap_vegs = db.rows(sql"SELECT name, qty WHERE price < 1.00 ORDER BY name")
```

We are going to assume that there are three matching records. So, the variable `cheap_vegs` is now pointing to the first record as an iterator. For example:

ptr |name       |qty
----|-----------|---
*   |carrot     | 20
-   |green bean |100
-   |squash     | 32

Every time a new record is pulled from from `cheap_vegs` the iterator advances to the next.

```nim
var first_veg = cheap_vegs
echo $first_veg[0] & ": " & $first_veg[1]  # prints "carrot: 20"
```

Notice that this is a sequence, so the columns are referenced by number.
And, now the `cheap_vegs` iterator has moved to the next row.

ptr |name       |qty
----|-----------|---
-   |carrot     | 20
*   |green bean |100
-   |squash     | 32

Since `first_veg` contains the record, we can also access the column's data based on what type of column it is. In this case, the first column is a string, so use `.s`, and the second column is an integer, so use `.i`.

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

which prints

```
green bean: 100
squash: 32
```

### HANDLING NO RESULTS

If the query had return no results...

### GETTING FEWER (OR ONE)

You an get just the first matching record by ...

### SIDEBAR: UNDERSTANDING TYPES

## CREATING RECORDS

## UPDATING RECORDS

## DELETING RECORDS
