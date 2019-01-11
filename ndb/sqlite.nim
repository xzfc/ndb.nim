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
##  for x in db.rows(sql"select * from myTestTbl"):
##    echo x
##
##  let id = db.tryInsertId(sql"INSERT INTO myTestTbl (name,i,f) VALUES (?,?,?)",
##        "Item#1001", 1001, sqrt(1001.0))
##  echo "Inserted item: ", db.getValue(string, sql"SELECT name FROM myTestTbl WHERE id=?", id).unsafeGet
##
##  db.close()

{.deadCodeElim: on.}  # dce option deprecated

import strutils, wrappers/sqlite3, options

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

# Specific
proc setupQueryVar(db: DbConn, query: SqlQuery, args: seq[DbValue],
                   stmt: var Pstmt): bool {.raises: [].} =
  assert(not db.isNil, "Database not connected.")
  var idx: int32 = 0
  var rc = prepare_v2(db, query.cstring, query.string.len.cint, stmt, nil)
  if rc != SQLITE_OK:
    return false
  for arg in args:
    inc idx
    rc = db.bindVal(stmt, idx, arg)
    if rc != SQLITE_OK:
      return false
  return true

proc setupQuery(db: DbConn, query: SqlQuery, args: seq[DbValue]): Pstmt =
  if not setupQueryVar(db, query, args, result):
    dbError(db)

# Specific
proc tryNext(stmt: Pstmt): Option[bool] {.raises: [].} =
  ## Try to advance cursor by one row.
  case step(stmt):
  of SQLITE_ROW:  true.some  # Success, next row
  of SQLITE_DONE: false.some # Success, no more rows
  else:           bool.none  # Error

# Specific
proc tryFinalize(stmt: Pstmt): bool {.raises: [].} =
  ## Finalize statement, return ``true`` on success.
  finalize(stmt) == SQLITE_OK

# Common
proc next(stmt: Pstmt): bool =
  ## Advance cursor by one row.
  ## Return ``true`` if there are more rows.
  let a = stmt.tryNext
  if a.isSome:
    return a.unsafeGet
  else:
    dbError(stmt.db_handle)

# Common
proc finalize(stmt: Pstmt) =
  ## Finalize statement or raise DbError if not successful.
  if not stmt.tryFinalize:
    dbError(stmt.db_handle)

proc tryExec*(db: DbConn, query: SqlQuery,
              args: varargs[DbValue, dbValue]): bool {.
              tags: [ReadDbEffect, WriteDbEffect], raises: [].} =
  ## Tries to execute the query and returns true if successful, false otherwise.
  var stmt: sqlite3.Pstmt
  if not setupQueryVar(db, query, @args, stmt):
    return false
  if stmt.tryNext.isSome:
    result = stmt.tryFinalize

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

iterator rows*(db: DbConn, query: SqlQuery,
                     args: varargs[DbValue, dbValue]): Row {.
  tags: [ReadDbEffect].} =
  ## Executes the query and iterates over the result dataset.
  var stmt = setupQuery(db, query, @args)
  var L = column_count(stmt)
  var result = newRow(L)
  try:
    while stmt.next:
      setRow(stmt, result)
      yield result
  finally:
    stmt.finalize

iterator instantRows*(db: DbConn, query: SqlQuery,
                      args: varargs[DbValue, dbValue]): InstantRow
                      {.tags: [ReadDbEffect].} =
  ## Same as rows but returns a handle that can be used to get column values
  ## on demand using []. Returned handle is valid only within the iterator body.
  var stmt = setupQuery(db, query, @args)
  try:
    while stmt.next:
      yield stmt
  finally:
    stmt.finalize

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
  ## Same as rows but returns a handle that can be used to get column values
  ## on demand using []. Returned handle is valid only within the iterator body.
  var stmt = setupQuery(db, query, @args)
  try:
    setColumns(columns, stmt)
    while stmt.next:
      yield stmt
  finally:
    stmt.finalize

# Specific
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

# Specific
proc len*(row: InstantRow): int32 {.inline.} =
  ## Return number of columns in the row.
  column_count(row)

# Common
proc getRow*(db: DbConn, query: SqlQuery,
             args: varargs[DbValue, dbValue]): Option[Row]
             {.tags: [ReadDbEffect].} =
  ## Retrieves a single row.
  for row in db.rows(query, args):
    return row.some

# Common
proc getAllRows*(db: DbConn, query: SqlQuery,
                 args: varargs[DbValue, dbValue]): seq[Row]
                 {.tags: [ReadDbEffect].} =
  ## Executes the query and returns the whole result dataset.
  result = @[]
  for r in db.rows(query, args):
    result.add(r)

# Common
iterator fastRows*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): Row {.tags: [ReadDbEffect],
               deprecated.} =
  ## **Deprecated:** use ``rows`` instead.
  for r in rows(db, query, args): yield r

# Common
proc getValue*[T:DbValueTypes|DbValue](
    db: DbConn, query: SqlQuery, args: varargs[DbValue, dbValue]): Option[T]
    {.tags: [ReadDbEffect].} =
  ## Executes the query and returns the first column of the first row of the
  ## result dataset.
  for row in db.instantRows(query, args):
    return row[0, T].some

# Common
proc getValue*(db: DbConn, T: typedesc,
               query: SqlQuery, args: varargs[DbValue, dbValue]): Option[T]
               {.tags: [ReadDbEffect].} =
  getValue[T](db, query, args)

# Should be common
proc tryInsertID*(db: DbConn, query: SqlQuery,
                  args: varargs[DbValue, dbValue]): int64
                  {.tags: [WriteDbEffect], raises: [].} =
  ## Executes the query (typically "INSERT") and returns the
  ## generated ID for the row or -1 in case of an error.
  var stmt: sqlite3.Pstmt
  if not setupQueryVar(db, query, @args, stmt):
    return -1
  if step(stmt) != SQLITE_DONE: # TODO
    return -1
  if not stmt.tryFinalize:
    return -1
  return last_insert_rowid(db)

# Common
proc insertID*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): int64
               {.tags: [WriteDbEffect].} =
  ## Executes the query (typically "INSERT") and returns the
  ## generated ID for the row. For Postgre this adds
  ## ``RETURNING id`` to the query, so it only works if your primary key is
  ## named ``id``.
  result = tryInsertID(db, query, args)
  if result < 0: dbError(db)

# Should be common
proc execAffectedRows*(db: DbConn, query: SqlQuery,
                       args: varargs[DbValue, dbValue]): int64 {.
                       tags: [ReadDbEffect, WriteDbEffect].} =
  ## Executes the query (typically "UPDATE") and returns the
  ## number of affected rows.
  exec(db, query, args)
  result = changes(db)

# Specific
proc close*(db: DbConn) {.tags: [DbEffect].} =
  ## Closes the database connection.
  if sqlite3.close(db) != SQLITE_OK: dbError(db)

# Specific
proc open*(connection, user, password, database: string): DbConn {.
  tags: [DbEffect].} =
  ## opens a database connection. Raises `EDb` if the connection could not
  ## be established. Only the ``connection`` parameter is used for ``sqlite``.
  var db: DbConn
  if sqlite3.open(connection, db) == SQLITE_OK:
    result = db
  else:
    dbError(db)

# Specific
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
  
proc doFullDatabaseBackup*(srcConn : var DbConn, dstConn : var DbConn, srcDbName : string = "main" , dstDbName : string = "main" ) : int {.
  tags: [DbEffect].} =
  ## performs a hot database backup from the src to destionation db.
  ##
  ## this proc returns if the entire database is copied completely.
  ## the dstConn is not allowed to have any transactions open.
  ##
  ## never copy the database file directly while connections attached to it.
  ## the default of the src and destination database name is "main".
  ##
  ## the the src and destination db could be of type in memory or file based.
  ## just ensure that the dest db is completely empty (or not existent)
  ## and the page_size is equal to the src db (see pragma page_size)
  ##
  ## for more information please look at https://www.sqlite.org/backup.html
  var pBackup : PSQLite3Backup

  pBackup = dstConn.sqlite3_backup_init(dstDbName,srcConn,srcDbName)
  
  if pBackup.isNil:
    # backup errcode is written into the dest connection
    dbError(dstConn)
  else:
    # TODO: backup with pagecount (iterator)
    discard sqlite3.sqlite3_backup_step(pBackup,-1.int)
    discard sqlite3.sqlite3_backup_finish(pBackup)
  
  result = sqlite3.errcode(dstConn)  
