## A fork of `db_sqlite <https://nim-lang.org/docs/db_sqlite.html>`_, Nim's
## standard library higher level `SQLite`:idx: database wrapper.
##
## Parameter substitution
## ----------------------
##
## All ``db_*`` modules support the same form of parameter substitution.
## That is, using the ``?`` (question mark) to signify the place where a
## value should be placed. For example:
##
## .. code-block:: Nim
##     sql"INSERT INTO myTable (colA, colB, colC) VALUES (?, ?, ?)"
##
## Examples
## --------
##
## The following examples are same as for db_sqlite.
##
## Opening a connection to a database
## ==================================
##
## .. code-block:: Nim
##     import db_sqlite
##     let db = open("mytest.db", "", "", "")  # user, password, database name can be nil
##     db.close()
##
## Creating a table
## ================
##
## .. code-block:: Nim
##      db.exec(sql"DROP TABLE IF EXISTS myTable")
##      db.exec(sql("""CREATE TABLE myTable (
##                       id integer,
##                       name varchar(50) not null)"""))
##
## Inserting data
## ==============
##
## .. code-block:: Nim
##     db.exec(sql"INSERT INTO myTable (id, name) VALUES (0, ?)",
##             "Jack")
##
## Larger example
## ==============
##
## .. code-block:: nim
##
##  import db_sqlite, math
##
##  let db = open("mytest.db", "", "", "")
##
##  db.exec(sql"Drop table if exists myTestTbl")
##  db.exec(sql("""create table myTestTbl (
##       Id    INTEGER PRIMARY KEY,
##       Name  VARCHAR(50) NOT NULL,
##       i     INT(11),
##       f     DECIMAL(18,10))"""))
##
##  db.exec(sql"BEGIN")
##  for i in 1..1000:
##    db.exec(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
##          "Item#" & $i, i, sqrt(i.float))
##  db.exec(sql"COMMIT")
##
##  for x in db.fastRows(sql"select * from myTestTbl"):
##    echo x
##
##  let id = db.tryInsertId(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
##        "Item#1001", 1001, sqrt(1001.0))
##  echo "Inserted item: ", db.getValue(string, sql"SELECT name FROM myTestTbl WHERE id=?", id).unsafeGet
##
##  db.close()

{.deadCodeElim: on.}  # dce option deprecated

import strutils, sqlite3, options

import db_common
export db_common

type
  DbValueKind* = enum
    ## Kind of value, corresponds to one of SQLite
    ## `Fundamental Datatypes <https://www.sqlite.org/c3ref/c_blob.html>`_.
    dvkInt    ## SQLITE_INTEGER, 64-bit signed integer
    dvkFloat  ## SQLITE_FLOAT, 64-bit IEEE floating point number
    dvkString ## SQLITE_TEXT, string
    dvkBlob   ## SQLITE_BLOB, BLOB
    dvkNull   ## SQLITE_NULL, NULL
  DbValueTypes* = int64|float|string|DbBlob|DbNull ## \
    ## Possible value types
  DbBlob* = distinct string ## SQLite BLOB value.
  DbNull* = object          ## SQLite NULL value.
  DbValue* = object
    ## SQLite value.
    case kind*: DbValueKind
    of dvkInt:
      i*: int64
    of dvkFloat:
      f*: float
    of dvkString:
      s*: string
    of dvkBlob:
      b*: DbBlob
    of dvkNull:
      discard
  DbConn* = PSqlite3  ## encapsulates a database connection
  Row* = seq[DbValue] ## a row of a dataset
  InstantRow* = Pstmt ## a handle that can be used to get a row's column
                      ## text on demand
{.deprecated: [TRow: Row, TDbConn: DbConn].}

proc `==`*(a: DbBlob, b: DbBlob): bool =
  ## Compare two blobs.
  a.string == b.string

proc `==`*(a: DbValue, b: DbValue): bool =
  ## Compare two DB values.
  if a.kind != b.kind:
    false
  else:
    case a.kind
    of dvkInt:    a.i == b.i
    of dvkFloat:  a.f == b.f
    of dvkString: a.s == b.s
    of dvkBlob:   a.b == b.b
    of dvkNull:   true

proc dbError*(db: DbConn) {.noreturn.} =
  ## Raises a DbError exception.
  var e: ref DbError
  new(e)
  e.msg = $sqlite3.errmsg(db)
  raise e

proc dbQuote*(s: string): string =
  ## DB quotes the string. Escaping values to generate SQL queries is not
  ## recommended, bind values using the ``?`` (question mark) instead.
  result = "'"
  for c in items(s):
    if c == '\'': add(result, "''")
    else: add(result, c)
  add(result, '\'')

proc dbQuote*(s: DbBlob): string =
  ## DB quotes the blob.
  result = "x'"
  for c in items(s.string):
    add(result, toHex(c.byte))
  add(result, '\'')

proc `$`*(v: DbValue): string =
  case v.kind
  of dvkInt:    $v.i
  of dvkFloat:  $v.f
  of dvkString: v.s.dbQuote
  of dvkBlob:   v.b.dbQuote
  of dvkNull:   "NULL"

proc bindVal(db: DbConn, stmt: sqlite3.Pstmt, idx: int32, value: DbValue): int32
             {. raises: [] .} =
  case value.kind:
  of dvkInt:
    bind_int64(stmt, idx, value.i)
  of dvkFloat:
    bind_double(stmt, idx, value.f)
  of dvkString:
    try:
      bind_text(stmt, idx, value.s.cstring, value.s.len.int32, SQLITE_TRANSIENT)
    except Exception:
      # Compiler thinks that bind_text can raise an exception since the last
      # argument is proc. But we pass an SQLITE_TRANSIENT constant here, it is
      # not called by SQLite, so exception is never happens.
      -1
  of dvkBlob:
    try:
      bind_blob(stmt, idx, value.b.string.cstring, value.b.string.len.int32, SQLITE_TRANSIENT)
    except Exception:
      # Never happens, see above.
      -1
  of dvkNull:
    bind_null(stmt, idx)

proc dbValue*(v: DbValue): DbValue =
  ## Return ``v`` as is.
  v

proc dbValue*(v: int|int32|int64|uint): DbValue =
  ## Wrap integer value.
  DbValue(kind: dvkInt, i: v.int64)

proc dbValue*(v: float): DbValue =
  ## Wrap float value.
  DbValue(kind: dvkFloat, f: v)

proc dbValue*(v: string): DbValue =
  ## Wrap string value.
  DbValue(kind: dvkString, s: v)

proc dbValue*(v: DbBlob): DbValue =
  ## Wrap BLOB value.
  DbValue(kind: dvkBlob, b: v)

proc dbValue*(v: DbNull): DbValue =
  ## Wrap NULL value.
  DbValue(kind: dvkNull)

when NimMinor >= 19:
  proc dbValue*(v: type(nil)): DbValue =
    ## Wrap NULL value.
    ## Caveat: doesn't compile on 0.19.0 release, see
    ## https://github.com/nim-lang/Nim/pull/9231.
    DbValue(kind: dvkNull)

proc dbValue*[T](v: Option[T]): DbValue =
  ## Wrap value of type T or NULL.
  if v.isSome:
    v.unsafeGet.dbValue
  else:
    DbValue(kind: dvkNull)

proc setupQueryVar(db: DbConn, query: SqlQuery, args: seq[DbValue],
                   stmt: var Pstmt): int {.raises: [].} =
  assert(not db.isNil, "Database not connected.")
  var idx: int32 = 0
  var rc = prepare_v2(db, query.cstring, query.string.len.cint, stmt, nil)
  if rc != SQLITE_OK:
    return rc
  for arg in args:
    inc idx
    rc = db.bindVal(stmt, idx, arg)
    if rc != SQLITE_OK:
      return rc
  return SQLITE_OK

proc setupQuery(db: DbConn, query: SqlQuery, args: seq[DbValue]): Pstmt =
  if setupQueryVar(db, query, args, result) != SQLITE_OK:
    dbError(db)

proc tryExec*(db: DbConn, query: SqlQuery,
              args: varargs[DbValue, dbValue]): bool {.
              tags: [ReadDbEffect, WriteDbEffect].} =
  ## Tries to execute the query and returns true if successful, false otherwise.
  var stmt: sqlite3.Pstmt
  if setupQueryVar(db, query, @args, stmt) != SQLITE_OK:
    return false
  let x = step(stmt)
  if x in {SQLITE_DONE, SQLITE_ROW}:
    result = finalize(stmt) == SQLITE_OK

proc exec*(db: DbConn, query: SqlQuery, args: varargs[DbValue, dbValue]) {.
  tags: [ReadDbEffect, WriteDbEffect].} =
  ## Executes the query and raises DbError if not successful.
  if not tryExec(db, query, args): dbError(db)

proc newRow(L: int): Row =
  newSeq(result, L)
  for i in 0..L-1: result[i] = DbValue(kind: dvkNull)

proc columnValue[T:DbValueTypes|DbValue](stmt: Pstmt, col: int32): T {.inline.} =
  when T is int64:
    stmt.column_int64(col)
  elif T is float:
    stmt.column_double(col)
  elif T is string:
    $column_text(stmt, col)
  elif T is DbBlob:
    let blob = column_blob(stmt, col)
    let bytes = column_bytes(stmt, col)
    var s = newString(bytes)
    if bytes != 0:
      copyMem(addr(s[0]), blob, bytes)
    DbBlob s
  elif T is DbNull:
    DbNull()
  elif T is DbValue:
    case stmt.column_type(col):
    of SQLITE_INTEGER:
      DbValue(kind: dvkInt,    i: columnValue[int64](stmt, col))
    of SQLITE_FLOAT:
      DbValue(kind: dvkFloat,  f: columnValue[float](stmt, col))
    of SQLITE_TEXT:
      DbValue(kind: dvkString, s: columnValue[string](stmt, col))
    of SQLITE_BLOB:
      DbValue(kind: dvkBlob,   b: columnValue[DbBlob](stmt, col))
    of SQLITE_NULL:
      DbValue(kind: dvkNull)
    else:
      DbValue(kind: dvkNull)

proc setRow(stmt: Pstmt, r: var Row) =
  let L = column_count(stmt)
  setLen(r, L)
  for col in 0'i32 ..< L:
    r[col] = columnValue[DbValue](stmt, col)

iterator fastRows*(db: DbConn, query: SqlQuery,
                     args: varargs[DbValue, dbValue]): Row {.
  tags: [ReadDbEffect].} =
  ## Executes the query and iterates over the result dataset.
  ##
  ## This is very fast, but potentially dangerous.  Use this iterator only
  ## if you require **ALL** the rows.
  ##
  ## Breaking the fastRows() iterator during a loop will cause the next
  ## database query to raise a DbError exception ``unable to close due to ...``.
  var stmt = setupQuery(db, query, @args)
  var L = (column_count(stmt))
  var result = newRow(L)
  while step(stmt) == SQLITE_ROW:
    setRow(stmt, result)
    yield result
  if finalize(stmt) != SQLITE_OK: dbError(db)

iterator instantRows*(db: DbConn, query: SqlQuery,
                      args: varargs[DbValue, dbValue]): InstantRow
                      {.tags: [ReadDbEffect].} =
  ## Same as fastRows but returns a handle that can be used to get column values
  ## on demand using []. Returned handle is valid only within the iterator body.
  var stmt = setupQuery(db, query, @args)
  while step(stmt) == SQLITE_ROW:
    yield stmt
  if finalize(stmt) != SQLITE_OK: dbError(db)

proc toTypeKind(t: var DbType; x: int32) =
  case x
  of SQLITE_INTEGER:
    t.kind = dbInt
    t.size = 8
  of SQLITE_FLOAT:
    t.kind = dbFloat
    t.size = 8
  of SQLITE_BLOB: t.kind = dbBlob
  of SQLITE_NULL: t.kind = dbNull
  of SQLITE_TEXT: t.kind = dbVarchar
  else: t.kind = dbUnknown

proc setColumns(columns: var DbColumns; x: PStmt) =
  let L = column_count(x)
  setLen(columns, L)
  for i in 0'i32 ..< L:
    columns[i].name = $column_name(x, i)
    columns[i].typ.name = $column_decltype(x, i)
    toTypeKind(columns[i].typ, column_type(x, i))
    columns[i].tableName = $column_table_name(x, i)

iterator instantRows*(db: DbConn; columns: var DbColumns; query: SqlQuery,
                      args: varargs[DbValue, dbValue]): InstantRow
                      {.tags: [ReadDbEffect].} =
  ## Same as fastRows but returns a handle that can be used to get column values
  ## on demand using []. Returned handle is valid only within the iterator body.
  var stmt = setupQuery(db, query, @args)
  setColumns(columns, stmt)
  while step(stmt) == SQLITE_ROW:
    yield stmt
  if finalize(stmt) != SQLITE_OK: dbError(db)

when NimMinor >= 19:
  proc `[]`*(row: InstantRow, col: int32, T: typedesc=string): T {.inline.} =
    ## Return value for given column of the row.
    ## ``T`` has to be one of ``DbValueTypes`` or ``DbValue``.
    columnValue[T](row, col)
else:
  proc `[]`*(row: InstantRow, col: int32, T: typedesc): T {.inline.} =
    ## Return value for given column of the row.
    ## ``T`` has to be one of ``DbValueTypes`` or ``DbValue``.
    columnValue[T](row, col)
  proc `[]`*(row: InstantRow, col: int32): string {.inline.} =
    ## Shortcut for ``row[col, string]``.
    row[col, string]

proc len*(row: InstantRow): int32 {.inline.} =
  ## Return number of columns in the row.
  column_count(row)

proc getRow*(db: DbConn, query: SqlQuery,
             args: varargs[DbValue, dbValue]): Option[Row]
             {.tags: [ReadDbEffect].} =
  ## Retrieves a single row. If the query doesn't return any rows, this proc
  ## will return a Row with empty strings for each column.
  var stmt = setupQuery(db, query, @args)
  if step(stmt) == SQLITE_ROW:
    let L = column_count(stmt)
    var row = newRow(L)
    setRow(stmt, row)
    result = row.some
  if finalize(stmt) != SQLITE_OK:
    dbError(db)

proc getAllRows*(db: DbConn, query: SqlQuery,
                 args: varargs[DbValue, dbValue]): seq[Row]
                 {.tags: [ReadDbEffect].} =
  ## Executes the query and returns the whole result dataset.
  result = @[]
  for r in fastRows(db, query, args):
    result.add(r)

iterator rows*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): Row {.tags: [ReadDbEffect].} =
  ## Same as `FastRows`, but slower and safe.
  for r in fastRows(db, query, args): yield r

proc getValue*[T:DbValueTypes|DbValue](
    db: DbConn, query: SqlQuery, args: varargs[DbValue, dbValue]): Option[T]
    {.tags: [ReadDbEffect].} =
  ## Executes the query and returns the first column of the first row of the
  ## result dataset.
  var stmt = setupQuery(db, query, @args)
  if step(stmt) == SQLITE_ROW:
    result = columnValue[T](stmt, 0).some
  else:
    result = T.none
  if finalize(stmt) != SQLITE_OK: dbError(db)

proc getValue*(db: DbConn, T: typedesc,
               query: SqlQuery, args: varargs[DbValue, dbValue]): Option[T]
               {.tags: [ReadDbEffect].} =
  getValue[T](db, query, args)

proc tryInsertID*(db: DbConn, query: SqlQuery,
                  args: varargs[DbValue, dbValue]): int64
                  {.tags: [WriteDbEffect], raises: [].} =
  ## Executes the query (typically "INSERT") and returns the
  ## generated ID for the row or -1 in case of an error.
  var stmt: sqlite3.Pstmt
  if setupQueryVar(db, query, @args, stmt) != SQLITE_OK:
    return -1
  if step(stmt) != SQLITE_DONE:
    return -1
  if finalize(stmt) != SQLITE_OK:
    return -1
  return last_insert_rowid(db)

proc insertID*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): int64
               {.tags: [WriteDbEffect].} =
  ## Executes the query (typically "INSERT") and returns the
  ## generated ID for the row. For Postgre this adds
  ## ``RETURNING id`` to the query, so it only works if your primary key is
  ## named ``id``.
  result = tryInsertID(db, query, args)
  if result < 0: dbError(db)

proc execAffectedRows*(db: DbConn, query: SqlQuery,
                       args: varargs[DbValue, dbValue]): int64 {.
                       tags: [ReadDbEffect, WriteDbEffect].} =
  ## Executes the query (typically "UPDATE") and returns the
  ## number of affected rows.
  exec(db, query, args)
  result = changes(db)

proc close*(db: DbConn) {.tags: [DbEffect].} =
  ## Closes the database connection.
  if sqlite3.close(db) != SQLITE_OK: dbError(db)

proc open*(connection, user, password, database: string): DbConn {.
  tags: [DbEffect].} =
  ## opens a database connection. Raises `EDb` if the connection could not
  ## be established. Only the ``connection`` parameter is used for ``sqlite``.
  var db: DbConn
  if sqlite3.open(connection, db) == SQLITE_OK:
    result = db
  else:
    dbError(db)

proc setEncoding*(connection: DbConn, encoding: string): bool {.
  tags: [DbEffect].} =
  ## Sets the encoding of a database connection, returns true for
  ## success, false for failure.
  ##
  ## Note that the encoding cannot be changed once it's been set.
  ## According to SQLite3 documentation, any attempt to change
  ## the encoding after the database is created will be silently
  ## ignored.
  exec(connection, sql"PRAGMA encoding = ?", encoding)
  result = getValue[string](connection, sql"PRAGMA encoding") == encoding.some
