import times
import strutils

const mode {.intdefine.} = 1

when mode == 0:
  import db_sqlite
  const name = "db_sqlite"
else:
  import ndb/sqlite
  const name = "ndb/sqlite"

template benchmark(benchmarkName: string, code: untyped) =
  var worst, best, total: float
  const attempts = 10
  for i in 0..<attempts:
    let t0 = epochTime()
    code
    let elapsed = epochTime() - t0

    if i == 0 or elapsed < best:
      best = elapsed
    if i == 0 or elapsed > worst:
      worst = elapsed
    total += elapsed
  let avg = total / attempts
  echo "$1 $2 $3 $4".format(
    benchmarkName.alignLeft(30),
    formatFloat(best,  format = ffDecimal, precision = 3),
    formatFloat(avg,   format = ffDecimal, precision = 3),
    formatFloat(worst, format = ffDecimal, precision = 3),
  )

echo "$1  best   avg worst".format(alignLeft("Benchmarking " & name, 30))

let db = open(":memory:", "", "", "")

db.exec sql"""
  CREATE TABLE t1 (
     id INTEGER PRIMARY KEY,
     v1 INTEGER NOT NULL,
     v2 INTEGER NOT NULL,
     v3 INTEGER NOT NULL
  )
"""

db.exec sql"""
  CREATE TABLE t2 (
     id INTEGER PRIMARY KEY,
     v1 TEXT NOT NULL,
     v2 TEXT NOT NULL,
     v3 TEXT NOT NULL
  )
"""

for i in 0..10000:
  db.exec sql"INSERT INTO t1 VALUES(?, ?, ?, ?)",
          i, i, i, i
  db.exec sql"INSERT INTO t2 VALUES(?, ?, ?, ?)",
          i, "foo", "bar", "baz"

benchmark "insert integer":
  for i in 0..10000:
    db.exec sql"INSERT OR IGNORE INTO t1 VALUES(?, ?, ?, ?)",
            i, i, i, i

benchmark "insert integer as string":
  for i in 0..10000:
    db.exec sql"INSERT OR IGNORE INTO t1 VALUES(?, ?, ?, ?)",
            $i, $i, $i, $i

when mode == 1: benchmark "select integer x100":
  for retry in 0..100:
    var sum = 0'i64
    for row in db.instantRows sql"SELECT * FROM t1":
      sum += row[0, int64] +
             row[1, int64] +
             row[2, int64] +
             row[3, int64]
    doAssert sum == 200020000

benchmark "select integer as string x100":
  for retry in 0..100:
    var sum = 0'i64
    for row in db.instantRows sql"SELECT * FROM t1":
      sum += row[0].parseInt +
             row[1].parseInt +
             row[2].parseInt +
             row[3].parseInt
    doAssert sum == 200020000

benchmark "insert string":
  for i in 0..10000:
    db.exec sql"INSERT OR IGNORE INTO t2 VALUES(?, ?, ?, ?)",
            i, "foo", "bar", "baz"

benchmark "select string x100":
  for retry in 0..100:
    for row in db.instantRows sql"SELECT * FROM t2":
      doAssert row[1] & row[2] & row[3] == "foobarbaz"

db.close()
