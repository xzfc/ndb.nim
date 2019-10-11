import ndb/postgres
import options
import times
import unittest

proc test_open(): DbConn =
  open("postgres", "postgres", "", "postgres")

suite "Examples":
  test "Opening a connection to a database":
    let db = test_open()
    db.close()
  test "Creating a table":
    let db = test_open()
    db.exec(sql"DROP TABLE IF EXISTS myTable")
    db.exec(sql("""CREATE TABLE myTable (
                     id integer,
                     name varchar(50) not null)"""))
    db.close()
  test "Inserting data":
    let db = test_open()
    db.exec(sql"DROP TABLE IF EXISTS myTable")
    db.exec(sql("""CREATE TABLE myTable (
                     id integer,
                     name varchar(50) not null)"""))
    db.exec(sql"INSERT INTO myTable (id, name) VALUES (0, $1)",
            "Dominik")
    db.close()
#  test "Larger example":
#    let db = test_open()
#
#    db.exec(sql"Drop table if exists myTestTbl")
#    db.exec(sql("""create table myTestTbl (
#         Id    INTEGER PRIMARY KEY,
#         Name  VARCHAR(50) NOT NULL,
#         i     INT(11),
#         f     DECIMAL(18,10))"""))
#
#    db.exec(sql"BEGIN")
#    for i in 1..1000:
#      db.exec(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
#            "Item#" & $i, i, sqrt(i.float))
#    db.exec(sql"COMMIT")
#
#    for x in db.rows(sql"select * from myTestTbl"):
#      # echo x
#      discard x
#
#    let id = db.tryInsertId(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
#          "Item#1001", 1001, sqrt(1001.0))
#    discard db.getValue(string, sql"SELECT name FROM myTestTbl WHERE id=?", id).unsafeGet
#
#    db.close()
#  test "readme.md":
#    #import ndb/sqlite
#    let db = test_open()
#
#    # Insert NULL
#    db.exec(sql"CREATE TABLE foo (a, b)")
#    db.exec(sql"INSERT INTO foo VALUES (?, ?)", 1, DbNull())
#
#    # Insert binary blob
#    db.exec(sql"CREATE TABLE blobs (a BLOB)")
#    db.exec(sql"INSERT INTO blobs VALUES (?)", DbBlob "\x00\x01\x02\x03")
#    let blobValue = db.getAllRows(sql"SELECT * FROM BLOBS")[0][0].b
#
#    db.close()
#
#    discard blobValue

suite "Select value of type":
  test "bool":
    let db = test_open()
    let rows = db.getRow(sql "SELECT true").unsafeGet
    check rows == @[DbValue(kind: dvkBool, b: true)]
    db.close()
  test "integer":
    let db = test_open()
    let rows = db.getRow(sql "SELECT 3").unsafeGet
    check rows == @[DbValue(kind: dvkInt, i: 3)]
    db.close()
  test "real":
    let db = test_open()
    let rows = db.getRow(sql "SELECT 1.3::float8").unsafeGet
    check rows == @[DbValue(kind: dvkFloat, f: 1.3)]
    db.close()
  test "empty text":
    let db = test_open()
    let rows = db.getRow(sql "SELECT ''").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "")]
    db.close()
  test "nonempty text":
    let db = test_open()
    let rows = db.getRow(sql "SELECT 'foo'").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "foo")]
    db.close()
  test "datetime":
    let db = test_open()
    let rows = db.getRow(sql "SELECT '2006-01-02T15:04:05-07'::timestamptz").unsafeGet
    let dt = initDateTime(2, mJan, 2006, 22, 4, 5, utc())
    check rows == @[DbValue(kind: dvkTimestamptz, t: dt)]
    db.close()
  test "null":
    let db = test_open()
    let rows = db.getRow(sql "SELECT NULL").unsafeGet
    check rows == @[DbValue(kind: dvkNull)]
    db.close()

suite "Bind value of type":
  test "int":
    let db = test_open()
    let rows = db.getRow(sql "SELECT pg_typeof($1)::TEXT", 0).unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "bigint")]
    db.close()
  test "float":
    let db = test_open()
    let rows = db.getRow(sql "SELECT pg_typeof($1)::TEXT", 1.3).unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "double precision")]
    db.close()
  test "string":
    let db = test_open()
    let rows = db.getRow(sql "SELECT pg_typeof($1)::TEXT", "").unsafeGet
    check rows == @[DbValue(kind: dvkString, s: "text")]
    db.close()
  test "null (DbNull)":
    let db = test_open()
    let rows = db.getRow(sql "SELECT $1::INT is NULL", DbNull()).unsafeGet
    check rows == @[DbValue(kind: dvkBool, b: true)]
    db.close()
  test "null (nil)":
    when NimMinor <= 19:
      # See dbValue(nil) doc
      skip()
    else:
      let db = test_open()
      let rows = db.getRow(sql "SELECT $1::INT is NULL", nil).unsafeGet
      check rows == @[DbValue(kind: dvkBool, b: true)]
      db.close()

suite "getRow()":
  test "empty":
    let db = test_open()
    let row = db.getRow(sql"SELECT 'a' WHERE 1=0")
    check row.isNone
    db.close()
  test "one":
    let db = test_open()
    let row = db.getRow(sql"SELECT 'a'")
    check row == some(@[dbValue "a"])
    db.close()
  test "two":
    let db = test_open()
    let row = db.getRow(sql"SELECT 'a' UNION SELECT 'b'")
    check row == some(@[dbValue "a"])
    db.close()

#suite "getValue()":
#  test "none":
#    let db = test_open()
#    let val = db.getValue(int64, sql"SELECT 'a' WHERE 1=0")
#    check val.isNone
#    db.close()
#  test "some int":
#    let db = test_open()
#    let val = db.getValue(int64, sql"SELECT '1234'")
#    check val == 1234i64.some
#    db.close()
#  test "some string":
#    let db = test_open()
#    let val = db.getValue(string, sql"SELECT 'abcd'")
#    check val == "abcd".some
#    db.close()

suite "various":
  test "bind multiple statements":
    let db = test_open()
    let rows = db.getAllRows(sql "SELECT $1, $2, $3, $4", "a", "b", "c", "d")
    check rows == @[@[
      DbValue(kind: dvkString, s: "a"),
      DbValue(kind: dvkString, s: "b"),
      DbValue(kind: dvkString, s: "c"),
      DbValue(kind: dvkString, s: "d"),
    ]]
    db.close()

  test "multiple rows":
    let db = test_open()
    let rows = db.getAllRows(sql """
      SELECT 'a' UNION ALL SELECT 'b' UNION ALL SELECT 'c' UNION ALL SELECT 'd'
    """)
    check rows == @[
      @[DbValue(kind: dvkString, s: "a")],
      @[DbValue(kind: dvkString, s: "b")],
      @[DbValue(kind: dvkString, s: "c")],
      @[DbValue(kind: dvkString, s: "d")],
    ]
    db.close()

  test "bind limit":
    let db = test_open()
    let rows = db.getAllRows(sql """
      SELECT 'a' UNION ALL SELECT 'b' UNION ALL SELECT 'c' UNION ALL SELECT 'd' LIMIT $1
    """, 2)
    check rows == @[
      @[DbValue(kind: dvkString, s: "a")],
      @[DbValue(kind: dvkString, s: "b")],
    ]
    db.close()

  test "rows()":
    let db = test_open()
    db.exec sql"DROP TABLE IF EXISTS t1"
    db.exec sql"""
      CREATE TABLE t1 (
         Id    INTEGER PRIMARY KEY,
         S     TEXT
      )
    """
    db.exec sql"INSERT INTO t1 VALUES($1, $2)", 1, "foo"
    db.exec sql"INSERT INTO t1 VALUES($1, $2)", 2, "bar"
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

#  test "instantRows()":
#    let db = test_open()
#    db.exec sql"""
#      CREATE TABLE t1 (
#         Id    INTEGER PRIMARY KEY,
#         S     TEXT
#      )
#    """
#    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 1, "foo"
#    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 2, "bar"
#    var n = 0
#    for row in db.instantRows(sql"SELECT * FROM t1"):
#      case n
#      of 0:
#        check row[0, int64] == 1
#        check row[0] == "1"
#        check row[1] == "foo"
#      of 1:
#        check row[0, int64] == 2
#        check row[0] == "2"
#        check row[1] == "bar"
#      else:
#        check false
#      check row.len == 2
#      n.inc
#    check n == 2
#    db.close()
#
  test "rows() break":
    let db = test_open()
    db.exec sql"DROP TABLE IF EXISTS t1"
    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
    db.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
    for row in db.rows(sql"SELECT * FROM t1"):
      if row[0] == dbValue 3: break
    db.close()

#  test "instantRows() break":
#    let db = test_open()
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
#    db.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
#    for row in db.instantRows(sql"SELECT * FROM t1"):
#      if row[0, int64] == 3: break
#    db.close()

  test "insertID()":
    let db = test_open()
    db.exec sql"DROP TABLE IF EXISTS t1"
    db.exec sql"CREATE TABLE t1 (id SERIAL PRIMARY KEY, value TEXT)"
    let id = db.insertID sql"INSERT INTO t1(value) VALUES ('a')"
    check id == 1
    db.close()

#suite "Prepared statement finalization":
#
#  test "tryExec() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
#    check: not db.tryExec(sql"INSERT INTO t1 VALUES (1)", 123)
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "tryExec() finalizes the statement (execution failure)":
#    let db = test_open()
#    # insertion will always fail
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY, CHECK (0))"
#    check: not db.tryExec(sql"INSERT INTO t1 VALUES (1)")
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "exec() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
#    expect DbError: db.exec(sql"INSERT INTO t1 VALUES (1)", 123)
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "exec() finalizes the statement (execution failure)":
#    let db = test_open()
#    # insertion will always fail
#    db.exec sql"DROP TABLE IF EXISTS t1"
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY, CHECK (false))"
#    expect DbError: db.exec(sql"INSERT INTO t1 VALUES (1)")
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "rows() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    expect DbError:
#      for row in db.rows(sql"SELECT 1", 123): discard
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  # TODO: find a way to trigger execution failure for `rows()`.
#
#  test "instantRows() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    expect DbError:
#      for row in db.instantRows(sql"SELECT 1", 123): discard
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  # TODO: find a way to trigger execution failure for `instantRows()`.
#
#  test "instantRows() (with columns) finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    expect DbError:
#      var columns: DbColumns
#      for row in db.instantRows(columns, sql"SELECT 1", 123): discard
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  # TODO: find a way to trigger execution failure for `instantRows()` with columns.
#
#  test "tryInsertID() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
#    check: db.tryInsertID(sql"INSERT INTO t1 VALUES (1)", 123) == -1
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "tryInsertID() finalizes the statement (execution failure)":
#    let db = test_open()
#    # insertion will always fail
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY, CHECK (0))"
#    check: db.tryInsertID(sql"INSERT INTO t1 VALUES (1)") == -1
#    # this throws if there are unfinalized statements!
#    db.close()
#
#
#  test "insertID() finalizes the statement (invalid parameter list)":
#    let db = test_open()
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
#    expect DbError: discard db.insertID(sql"INSERT INTO t1 VALUES (1)", 123)
#    # this throws if there are unfinalized statements!
#    db.close()
#
#  test "insertID() finalizes the statement (execution failure)":
#    let db = test_open()
#    # insertion will always fail
#    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY, CHECK (0))"
#    expect DbError: discard db.insertID(sql"INSERT INTO t1 VALUES (1)")
#    # this throws if there are unfinalized statements!
#    db.close()
#
#suite "sugar":
#  test "one":
#    let db = test_open()
#    let row = db.getRow(sql"SELECT 'a'")
#    check row == some(@[?"a"])
#    db.close()
#
#  test "rows()":
#    let db = test_open()
#    db.exec sql"""
#      CREATE TABLE t1 (
#          Id    INTEGER PRIMARY KEY,
#          S     TEXT
#      )
#    """
#    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 1, "foo"
#    db.exec sql"INSERT INTO t1 VALUES(?, ?)", 2, "bar"
#    var n = 0
#    for row in db.rows(sql"SELECT * FROM t1"):
#      case n
#      of 0:
#        check row[0] == ?1
#        check row[1] == ?"foo"
#      of 1:
#        check row[0] == ?2
#        check row[1] == ?"bar"
#      else:
#        check false
#      check row.len == 2
#      n.inc
#    check n == 2
#    db.close()
#
  test "rows() break":
    let db = test_open()
    db.exec sql"DROP TABLE IF EXISTS t1"
    db.exec sql"CREATE TABLE t1 (id INTEGER PRIMARY KEY)"
    db.exec sql"INSERT INTO t1 VALUES(1),(2),(3),(4),(5)"
    for row in db.rows(sql"SELECT * FROM t1"):
      if row[0] == ?3: break
    db.close()
