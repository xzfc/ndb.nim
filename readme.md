# lowdb

_An ndb fork capable of working with nim 2.0_

A fork of [db_sqlite](https://nim-lang.org/docs/db_sqlite.html) and [db_postgres](https://nim-lang.org/docs/db_postgres.html), Nim's database libraries for Sqlite and Postgres, based on [ndb](https://github.com/xzfc/ndb.nim).

Warning: work in progress, API is a subject of change.

# Features
### General
  * No more empty strings as a default placeholder value.
    Empty string, ``NULL``, and an absence of a row are distinguished.

### SQLite:
  * Binding ``?`` parameters is done with native SQlite [`sqlite3_bind_*`](https://www.sqlite.org/c3ref/bind_blob.html)functions instead of stringifying and then escaping every parameter.
    As a result:
    * In addition to ``?``, the ``?NNN`` syntax is supported. See [sqlite3_varparam](https://www.sqlite.org/lang_expr.html#varparam).
    * Inserting binary blobs is handled in a proper way. See [Nim#5768](https://github.com/nim-lang/Nim/issues/5768).
    * It is possible to insert the `NULL` value.

# Example

```nim
import lowdb/sqlite
let db = open(":memory:", "", "", "")

# Insert NULL
db.exec(sql"CREATE TABLE foo (a, b)")
db.exec(sql"INSERT INTO foo VALUES (?, ?)", 1, DbNull())

# Insert binary blob
db.exec(sql"CREATE TABLE blobs (a BLOB)")
db.exec(sql"INSERT INTO blobs VALUES (?)", DbBlob "\x00\x01\x02\x03")
let blobValue = db.getAllRows(sql"SELECT * FROM BLOBS")[0][0].b

db.close()
```

# lowdb/postgres

Initial PostgreSQL support is provided. It is not complete yet.

# Why Fork ndb?
First up, we want to give a huge shoutout to the original author of the package, Albert Safin, who made this possible. We are thankful for the effort that went into this package and that has served us well over the years. 

Now why did we decide to fork?
We, the developers of norm, depend on this package and it staying up to date as well as adding more support of postgres features. This is particularly relevant for the (as of 09.02.2023 still upcoming) release of nim 2.0, which break this package and subsequently norm. Sadly, ndb appears to no longer be actively maintained and has become a bottleneck for developing norm.

As such we have decided to maintain our own fork of it, to be able to prepare norm for the upgrade to nim 2.0, the addition of asynchronous usage of postgres and maybe more in the future.