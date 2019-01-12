import ndb/sqlite
import math
import options
import sequtils
import unittest

suite "Examples":
  test "Opening a connection to a database":
    let db = open(":memory:", "", "", "")
    db.close()
  test "Creating a table":
    let db = open(":memory:", "", "", "")
    db.exec(sql"DROP TABLE IF EXISTS myTable")
    db.exec(sql("""CREATE TABLE myTable (
                     id integer,
                     name varchar(50) not null)"""))
    db.close()
  test "Inserting data":
    let db = open(":memory:", "", "", "")
    db.exec(sql("""CREATE TABLE myTable (
                     id integer,
                     name varchar(50) not null)"""))
    db.exec(sql"INSERT INTO myTable (id, name) VALUES (0, ?)",
            "Jack")
    db.close()
  test "Larger example":
    let db = open(":memory:", "", "", "")
  
    db.exec(sql"Drop table if exists myTestTbl")
    db.exec(sql("""create table myTestTbl (
         Id    INTEGER PRIMARY KEY,
         Name  VARCHAR(50) NOT NULL,
         i     INT(11),
         f     DECIMAL(18,10))"""))
  
    db.exec(sql"BEGIN")
    for i in 1..1000:
      db.exec(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
            "Item#" & $i, i, sqrt(i.float))
    db.exec(sql"COMMIT")
  
    for x in db.rows(sql"select * from myTestTbl"):
      # echo x
      discard x
  
    let id = db.tryInsertId(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
          "Item#1001", 1001, sqrt(1001.0))
    discard db.getValue(string, sql"SELECT name FROM myTestTbl WHERE id=?", id).unsafeGet
  
    db.close()
  test "readme.md":
    #import ndb/sqlite
    let db = open(":memory:", "", "", "")

    # Insert NULL
    db.exec(sql"CREATE TABLE foo (a, b)")
    db.exec(sql"INSERT INTO foo VALUES (?, ?)", 1, DbNull())

    # Insert binary blob
    db.exec(sql"CREATE TABLE blobs (a BLOB)")
    db.exec(sql"INSERT INTO blobs VALUES (?)", DbBlob "\x00\x01\x02\x03")
    let blobValue = db.getAllRows(sql"SELECT * FROM BLOBS")[0][0].b

    db.close()

suite "Select value of type":
  test "integer":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT 3").unsafeGet
    check rows == @[DbValue(kind: dvkInt, i: 3)]
    db.close()
  test "real":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT 1.3").unsafeGet
    check rows == @[DbValue(kind: dvkFloat, f: 1.3)]
    db.close()
  test "empty text":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT ''").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "")]
    db.close()
  test "nonempty text":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT 'foo'").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "foo")]
    db.close()
  test "empty blob":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT x''").unsafeGet
    check rows == @[DbValue(kind: dvkBlob, b: DbBlob "")]
    db.close()
  test "nonempty blob":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT x'313233'").unsafeGet
    check rows == @[DbValue(kind: dvkBlob, b: DbBlob "123")]
    db.close()
  test "blob with nul":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT x'007800'").unsafeGet
    check rows == @[DbValue(kind: dvkBlob, b: DbBlob "\0x\0")]
    check rows != @[DbValue(kind: dvkBlob, b: DbBlob "\0y\0")]
    db.close()
  test "blob with invalid utf8":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT x'00fe00'").unsafeGet
    check rows == @[DbValue(kind: dvkBlob, b: DbBlob "\0\xfe\0")]
    check rows != @[DbValue(kind: dvkBlob, b: DbBlob "\0\xff\0")]
    db.close()
  test "null":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT NULL").unsafeGet
    check rows == @[DbValue(kind: dvkNull)]
    db.close()

suite "Bind value of type":
  test "integer":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT typeof(?)", 0).unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "integer")]
    db.close()
  test "real":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT typeof(?)", 1.3).unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "real")]
    db.close()
  test "text":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT typeof(?)", "").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "text")]
    db.close()
  test "blob":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT typeof(?)", DbBlob "").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "blob")]
    db.close()
  test "null":
    let db = open(":memory:", "", "", "")
    let rows = db.getRow(sql "SELECT typeof(?)", DbNull()).unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "null")]
    db.close()

suite "getRow()":
  test "empty":
    let db = open(":memory:", "", "", "")
    let row = db.getRow(sql"SELECT 'a' WHERE 1=0")
    check row.isNone
    db.close()
  test "one":
    let db = open(":memory:", "", "", "")
    let row = db.getRow(sql"SELECT 'a'")
    check row == some(@[dbValue "a"])
    db.close()
  test "two":
    let db = open(":memory:", "", "", "")
    let row = db.getRow(sql"SELECT 'a' UNION SELECT 'b'")
    check row == some(@[dbValue "a"])
    db.close()

suite "getValue()":
  test "none":
    let db = open(":memory:", "", "", "")
    let val = db.getValue(int64, sql"SELECT 'a' WHERE 1=0")
    check val.isNone
    db.close()
  test "some int":
    let db = open(":memory:", "", "", "")
    let val = db.getValue(int64, sql"SELECT '1234'")
    check val == 1234i64.some
    db.close()
  test "some string":
    let db = open(":memory:", "", "", "")
    let val = db.getValue(string, sql"SELECT 'abcd'")
    check val == "abcd".some
    db.close()

suite "various":
  test "bind multiple statements":
    let db = open(":memory:", "", "", "")
    let rows = db.getAllRows(sql "SELECT ?, ?, ?, ?", "a", "b", "c", "d")
    check rows == @[@[
      DbValue(kind: dvkString, s: "a"),
      DbValue(kind: dvkString, s: "b"),
      DbValue(kind: dvkString, s: "c"),
      DbValue(kind: dvkString, s: "d"),
    ]]
    db.close()

  test "multiple rows":
    let db = open(":memory:", "", "", "")
    let rows = db.getAllRows(sql """
      SELECT 'a' UNION SELECT 'b' UNION SELECT 'c' UNION SELECT 'd'
    """)
    check rows == @[
      @[DbValue(kind: dvkString, s: "a")],
      @[DbValue(kind: dvkString, s: "b")],
      @[DbValue(kind: dvkString, s: "c")],
      @[DbValue(kind: dvkString, s: "d")],
    ]
    db.close()

  test "bind limit":
    let db = open(":memory:", "", "", "")
    let rows = db.getAllRows(sql """
      SELECT 'a' UNION SELECT 'b' UNION SELECT 'c' UNION SELECT 'd' LIMIT ?
    """, 2)
    check rows == @[
      @[DbValue(kind: dvkString, s: "a")],
      @[DbValue(kind: dvkString, s: "b")],
    ]
    db.close()

  test "rows()":
    let db = open(":memory:", "", "", "")
    db.exec sql"""
      CREATE TABLE t1 (
         Id    INTEGER PRIMARY KEY,
         S     TEXT
      )
    """
    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 1, "foo"
    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 2, "bar"
    var n = 0
    for row in db.rows(sql"SELECT * FROM t1"):
      case n
      of 0:
        check row[0] == dbValue 1
        check row[1] == dbValue "foo"
      of 1:
        check row[0] == dbValue 2
        check row[1] == dbValue "bar"
      else:
        check false
      check row.len == 2
      n.inc
    check n == 2
    db.close()

  test "instantRows()":
    let db = open(":memory:", "", "", "")
    db.exec sql"""
      CREATE TABLE t1 (
         Id    INTEGER PRIMARY KEY,
         S     TEXT
      )
    """
    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 1, "foo"
    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 2, "bar"
    var n = 0
    for row in db.instantRows(sql"SELECT * FROM t1"):
      case n
      of 0:
        check row[0, int64] == 1
        check row[0] == "1"
        check row[1] == "foo"
      of 1:
        check row[0, int64] == 2
        check row[0] == "2"
        check row[1] == "bar"
      else:
        check false
      check row.len == 2
      n.inc
    check n == 2
    db.close()

  test "rows() break":
    let db = open(":memory:", "", "", "")
    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
    db.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
    var n = 0
    for row in db.rows(sql"SELECT * FROM t1"):
      if row[0] == dbValue 3: break
    db.close()

  test "instantRows() break":
    let db = open(":memory:", "", "", "")
    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
    db.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
    var n = 0
    for row in db.instantRows(sql"SELECT * FROM t1"):
      if row[0, int64] == 3: break
    db.close()

  test "database_backup_inmemory":
  # test hot database backup. src and dst database can be file-based or memory-based
    var srcConn = open(":memory:", "", "", "")
    var dstConn = open(":memory:", "", "", "")

    srcConn.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
    srcConn.exec sql"BEGIN TRANSACTION"
    srcConn.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
    srcConn.exec sql"COMMIT"
   
    check srcConn.dumpDatabaseInto(dstConn) == 0
    
    for row in dstConn.instantRows(sql"SELECT * FROM t1 where id = 4"):
      check row[0, int64] == 4

    srcConn.close()
    dstConn.close()
