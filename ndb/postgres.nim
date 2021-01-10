## A fork of `db_postgres <https://nim-lang.org/docs/db_postgres.html>`_,
## Nim's standard library higher level `PostgreSQL`:idx: database wrapper.
##
## This is a work in progress, many procs are missing.
##
## Parameter substitution
## ======================
##
## Unlike ``ndb/sqlite``, you have to use ``$1, $2, $3, ...`` instead of
## ``?`` as a parameter placeholders.
##
## .. code-block:: Nim
##     sql"INSERT INTO myTable (colA, colB, colC) VALUES ($1, $2, $3)"
##
## Examples
## ========
##
## Opening a connection to a database
## ----------------------------------
##
## .. code-block:: Nim
##     import db_postgres
##     let db = open("localhost", "user", "password", "dbname")
##     db.close()
##
## Creating a table
## ----------------
##
## .. code-block:: Nim
##      db.exec(sql"DROP TABLE IF EXISTS myTable")
##      db.exec(sql("""CREATE TABLE myTable (
##                       id integer,
##                       name varchar(50) not null)"""))
##
## Inserting data
## --------------
##
## .. code-block:: Nim
##     db.exec(sql"INSERT INTO myTable (id, name) VALUES (0, $1)",
##             "Dominik")
##
## See also
## ========
##
## * `ndb/sqlite module <sqlite.html>`_ for SQLite database wrapper

import options
import strutils
import times
import wrappers/libpq

import db_common
export db_common

import macros
macro old(x: untyped): untyped =
  when defined(ndbPostgresOld):
    return x
  else:
    return newNimNode(nnkEmpty)

type
  DbConn* = PPGconn    ## Encapsulates a database connection.
  RowOld* = seq[string]## A row of a dataset. NULL database values will be
                       ## converted to nil.
  Row* = seq[DbValue]  ## A row of a dataset.
  InstantRow* = object ## A handle that can be used to get a row's column text on demand.
    res: PPGresult
    line: int
  SqlPrepared* = distinct string ## A identifier for the prepared queries.

  DbValueKind* = enum
    dvkBool
    dvkInt
    dvkFloat
    dvkString
    dvkTimestamptz
    dvkOther
    dvkNull
  DbValueTypes* = bool|int64|float64|string|DateTime|DbOther|DbNull ## Possible value types
  DbOther* = object
    oid*: Oid
    value*: string
  DbNull* = object          ## NULL value.
  DbValue* = object
    case kind*: DbValueKind
    of dvkBool:
      b*: bool
    of dvkInt:
      i*: int64
    of dvkFloat:
      f*: float64
    of dvkString:
      s*: string
    of dvkTimestamptz:
      t*: DateTime
    of dvkOther:
      o*: DbOther
    of dvkNull:
      discard

  DbParam = object
    types: POid
    typesSeq: seq[Oid]
    lengths: ptr cint
    lengthsSeq: seq[cint]
    formats: ptr cint
    formatsSeq: seq[cint]
    values: cstringArray

proc dbValue*(v: DbValue): DbValue =
  ## Return ``v`` as is.
  v

proc dbValue*(v: int|int8|int16|int32|int64|uint8|uint16|uint32): DbValue =
  ## Wrap integer value.
  DbValue(kind: dvkInt, i: v.int64)

proc dbValue*(v: float64): DbValue =
  ## Wrap float value.
  DbValue(kind: dvkFloat, f: v)

proc dbValue*(v: string): DbValue =
  ## Wrap string value.
  DbValue(kind: dvkString, s: v)

proc dbValue*(v: bool): DbValue =
  ## Wrap bool value.
  DbValue(kind: dvkBool, b: v)

proc dbValue*(v: DateTime): DbValue =
  ## Wrap DateTime value.
  DbValue(kind: dvkTimestamptz, t: v)

proc dbValue*(v: DbNull|type(nil)): DbValue =
  ## Wrap NULL value.
  ## Caveat: ``dbValue(nil)`` doesn't compile on Nim 0.19.x, see
  ## https://github.com/nim-lang/Nim/pull/9231.
  DbValue(kind: dvkNull)

template `?`*(v: typed): DbValue =
  ## Shortcut for ``dbValue``.
  dbValue(v)

proc dbValue*[T](v: Option[T]): DbValue =
  ## Wrap value of type T or NULL.
  if v.isSome:
    v.unsafeGet.dbValue
  else:
    DbValue(kind: dvkNull)

proc `==`*(a: DbValue, b: DbValue): bool =
  ## Compare two DB values.
  if a.kind != b.kind:
    false
  else:
    case a.kind
    of dvkBool:        a.b == b.b
    of dvkInt:         a.i == b.i
    of dvkFloat:       a.f == b.f
    of dvkString:      a.s == b.s
    of dvkTimestamptz: a.t == b.t
    of dvkOther:       a.o == b.o
    of dvkNull:        true

proc strdup(s: string): cstring =
  result = cast[cstring](alloc0(s.len+1))
  if s.len != 0:
    copyMem(result, s[0].unsafeAddr, s.len)

proc newDbParam(args: varargs[DbValue]): DbParam =
  if args.len == 0:
    return
  result.typesSeq = newSeq[Oid](args.len)
  result.types = result.typesSeq[0].addr
  result.lengthsSeq = newSeq[cint](args.len)
  result.lengths = result.lengthsSeq[0].addr
  result.formatsSeq = newSeq[cint](args.len)
  result.formats = result.formatsSeq[0].addr
  result.values = cast[cstringArray](alloc((args.len) * sizeof(cstring)))
  for i in 0..<args.len:
    case args[i].kind
    of dvkBool:
      result.values[i] = strdup((if args[i].b: "t" else: "f"))
      result.typesSeq[i] = 16
    of dvkInt:
      result.values[i] = ($args[i].i).strdup
      result.typesSeq[i] = 20
      # result.values[i] = "\0\0\0\0\0\0\x02\x01".strdup
      # result.lengthsSeq[i] = 8
      # result.formatsSeq[i] = 1
    of dvkFloat:
      result.values[i] = ($args[i].f).strdup
      result.typesSeq[i] = 701
    of dvkString:
      result.values[i] = ($args[i].s).strdup
      result.typesSeq[i] = 25
    of dvkTimestamptz:
      result.values[i] = ($args[i].t.format("yyyy-MM-dd HH:mm:sszz")).strdup
      result.typesSeq[i] = 1184
    of dvkOther:
      result.values[i] = args[i].o.value.strdup
      result.typesSeq[i] = args[i].o.oid
    of dvkNull:
      result.values[i] = nil

proc dealloc(binds: DbParam) =
  if binds.typesSeq.len == 0:
    return
  for i in 0..<binds.typesSeq.len:
    if binds.values[i] != nil:
      binds.values[i].dealloc
  dealloc(binds.values)

proc dbError*(db: DbConn) {.noreturn.} =
  ## Raises a DbError exception.
  var e: ref DbError
  new(e)
  e.msg = $pqErrorMessage(db)
  raise e

proc tryWithStmt(db: DbConn, query: SqlQuery, args: seq[DbValue],
                 expectedStatusType: ExecStatusType,
                 body: proc(res: PPGresult): bool {.raises: [], tags: [].}): bool =
  ## A common template dealing with statement initialization and finalization:
  ##
  ## 1. Initialize a statement.
  ## 2. Bind arguments.
  ## 3. Run `body`.
  ## 4. Finalize the statement.
  ## 5. Yield `true` on success and `false` on failure.
  ##
  ## `body` is assumed to yield `true` if it succeeds, and `false` otherwise.
  assert(not db.isNil, "Database not connected.")
  let param = newDbParam(args)
  var res = pqexecParams(db, query.cstring, args.len,
    param.types, param.values, param.lengths, param.formats, 0)
  param.dealloc()
  var ok = pqresultStatus(res) == expectedStatusType
  if ok:
    ok = body(res)
  pqclear(res)
  ok

template withStmt(db: DbConn, query: SqlQuery, args: varargs[DbValue],
                  body: untyped): untyped =
  ## A common template dealing with statement initialization and finalization:
  ##
  ## 1. Initialize a statement.
  ## 2. Bind arguments.
  ## 3. Run `body` (statement is available as `var stmt: sqlite.Pstmt`).
  ## 4. Finalize the statement.
  ## 5. Yield the result of evaluating the `body`.
  ##
  ## Unlike `tryWithStmt`, this throws a `DbError` in case of a failure!
  assert(not db.isNil, "Database not connected.")
  let param = newDbParam(args)
  var res {.inject.} = pqexecParams(db, query.cstring, args.len,
    param.types, param.values, param.lengths, param.formats, 0)
  param.dealloc()
  if pqresultStatus(res) != PGRES_TUPLES_OK: dbError(db)

  try:
    body
  finally:
    pqclear(res)

proc dbQuote*(s: string): string =
  ## DB quotes the string. Escaping values to generate SQL queries is not
  ## recommended, bind values using the ``$1`` instead.
  result = "'"
  for c in items(s):
    if c == '\'': add(result, "''")
    else: add(result, c)
  add(result, '\'')

proc `$`*(v: DbValue): string =
  case v.kind
  of dvkBool:
    if v.b: "t" else: "f"
  of dvkInt:          $v.i
  of dvkFloat:        $v.f
  of dvkString:       v.s.dbQuote
  of dvkTimestamptz:  v.t.format("yyyy-MM-dd HH:mm:sszz")
  of dvkOther:        v.o.value
  of dvkNull:         "NULL"

proc dbFormat(formatstr: SqlQuery, args: varargs[string]): string =
  result = ""
  var a = 0
  if args.len > 0 and not string(formatstr).contains("?"):
    dbError("""parameter substitution expects "?" """)
  if args.len == 0:
    return string(formatstr)
  else:
    for c in items(string(formatstr)):
      if c == '?':
        add(result, dbQuote(args[a]))
        inc(a)
      else:
        add(result, c)

proc tryExec*(db: DbConn, query: SqlQuery,
              args: varargs[string, `$`]): bool {.old, tags: [ReadDbEffect, WriteDbEffect].} =
  ## tries to execute the query and returns true if successful, false otherwise.
  var res = pqexecParams(db, dbFormat(query, args), 0, nil, nil,
                        nil, nil, 0)
  result = pqresultStatus(res) == PGRES_COMMAND_OK
  pqclear(res)

proc tryExec*(db: DbConn, stmtName: SqlPrepared,
              args: varargs[string, `$`]): bool {.old, tags: [
              ReadDbEffect, WriteDbEffect].} =
  ## tries to execute the query and returns true if successful, false otherwise.
  var arr = allocCStringArray(args)
  var res = pqexecPrepared(db, stmtName.string, int32(args.len), arr,
                           nil, nil, 0)
  deallocCStringArray(arr)
  result = pqresultStatus(res) == PGRES_COMMAND_OK
  pqclear(res)

proc exec*(db: DbConn, query: SqlQuery, args: varargs[DbValue, dbValue]) {.
  tags: [ReadDbEffect, WriteDbEffect].} =
  ## Executes the query and raises DbError if not successful.
  let param = newDbParam(args)
  var res = pqexecParams(db, query.cstring, args.len,
    param.types, param.values, param.lengths, param.formats, 0)
  param.dealloc()
  if pqresultStatus(res) != PGRES_COMMAND_OK: dbError(db)
  pqclear(res)

proc exec*(db: DbConn, stmtName: SqlPrepared,
          args: varargs[string]) {.old, tags: [ReadDbEffect, WriteDbEffect].} =
  var arr = allocCStringArray(args)
  var res = pqexecPrepared(db, stmtName.string, int32(args.len), arr,
                           nil, nil, 0)
  deallocCStringArray(arr)
  if pqResultStatus(res) != PGRES_COMMAND_OK: dbError(db)
  pqclear(res)

proc newRow(L: int): RowOld =
  newSeq(result, L)
  for i in 0..L-1: result[i] = ""

proc newRowEx(L: int): Row =
  newSeq(result, L)
  for i in 0..L-1: result[i] = dbValue DbNull()

proc setupQuery(db: DbConn, query: SqlQuery,
                args: varargs[string]): PPGresult =
  result = pqexec(db, dbFormat(query, args))
  if pqResultStatus(result) != PGRES_TUPLES_OK: dbError(db)

proc setupQuery(db: DbConn, stmtName: SqlPrepared,
                 args: varargs[string]): PPGresult =
  var arr = allocCStringArray(args)
  result = pqexecPrepared(db, stmtName.string, int32(args.len), arr,
                          nil, nil, 0)
  deallocCStringArray(arr)
  if pqResultStatus(result) != PGRES_TUPLES_OK: dbError(db)

proc prepare*(db: DbConn; stmtName: string, query: SqlQuery;
              nParams: int): SqlPrepared {.old.} =
  ## Create a new ``SqlPrepared`` statement.
  if nParams > 0 and not string(query).contains("$1"):
    dbError("parameter substitution expects \"$1\"")
  var res = pqprepare(db, stmtName, query.string, int32(nParams), nil)
  if pqResultStatus(res) != PGRES_COMMAND_OK: dbError(db)
  return SqlPrepared(stmtName)

proc setRow(res: PPGresult, r: var RowOld, line, cols: int32) =
  for col in 0'i32..cols-1:
    setLen(r[col], 0)
    let x = pqgetvalue(res, line, col)
    if x.isNil:
      r[col] = ""
    else:
      add(r[col], x)

proc parseDate1(s: string): DateTime =
  # TODO: parse optional fractional seconds
  # `select now();` => `2019-09-03 12:18:20.022531+00`
  # Reference: ISO 8601, https://www.postgresql.org/docs/11/datatype-datetime.html
  s.parse("yyyy-MM-dd HH:mm:sszz", utc())

proc parseDate(s: string): DateTime =
  # An ugly hack to get rid of ``{.tag: [TimeEffect].}``.
  # https://forum.nim-lang.org/t/3318#20981
  cast[proc (s: string): DateTime {.nimcall.}](parseDate1)(s)

proc setRow(res: PPGresult, r: var Row, line, cols: int32) =
  for col in 0'i32..<cols:
    if pqgetisnull(res, line, col) != 0:
      r[col] = dbValue(DbNull())
    else:
      let val = pqgetvalue(res, line, col)
      let oid = pqftype(res, col)
      r[col] = case oid:
      of 16: # bool
        DbValue(kind: dvkBool, b: val[0] == 't')
      of 20, 21, 23: # int8 int2 int4
        DbValue(kind: dvkInt, i: parseInt $val)
      of 700, 701: # float4 float8
        DbValue(kind: dvkFloat, f: parseFloat $val)
      of 1114, 1184: # timestamp timestamptz
        DbValue(kind: dvkTimestamptz, t: parseDate $val)
      of 25: # text
        DbValue(kind: dvkString, s: $val)
      else:
        DbValue(kind: dvkOther, o: DbOther(oid: oid, value: $val))

iterator rows*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): Row {.tags: [ReadDbEffect].} =
  ## Executes the query and iterates over the result dataset.
  db.withStmt(query, args):
    var L = pqNfields(res)
    var result = newRowEx(L)
    for i in 0'i32..<pqntuples(res):
      setRow(res, result, i, L)
      yield result

# Common
iterator fastRows*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): Row {.tags: [ReadDbEffect],
               deprecated:"use rows() instead.".} =
  for r in rows(db, query, args): yield r

iterator fastRows*(db: DbConn, stmtName: SqlPrepared,
                   args: varargs[string, `$`]): RowOld {.old, tags: [ReadDbEffect].} =
  ## executes the prepared query and iterates over the result dataset.
  var res = setupQuery(db, stmtName, args)
  var L = pqNfields(res)
  var result = newRow(L)
  for i in 0'i32..pqNtuples(res)-1:
    setRow(res, result, i, L)
    yield result
  pqClear(res)

iterator instantRows*(db: DbConn, query: SqlQuery,
                      args: varargs[string, `$`]): InstantRow
                      {.old, tags: [ReadDbEffect].} =
  ## same as fastRows but returns a handle that can be used to get column text
  ## on demand using []. Returned handle is valid only within iterator body.
  var res = setupQuery(db, query, args)
  for i in 0'i32..pqNtuples(res)-1:
    yield InstantRow(res: res, line: i)
  pqClear(res)

iterator instantRows*(db: DbConn, stmtName: SqlPrepared,
                      args: varargs[string, `$`]): InstantRow
                      {.old, tags: [ReadDbEffect].} =
  ## same as fastRows but returns a handle that can be used to get column text
  ## on demand using []. Returned handle is valid only within iterator body.
  var res = setupQuery(db, stmtName, args)
  for i in 0'i32..pqNtuples(res)-1:
    yield InstantRow(res: res, line: i)
  pqClear(res)

proc getColumnType(res: PPGresult, col: int) : DbType =
  ## returns DbType for given column in the row
  ## defined in pg_type.h file in the postgres source code
  ## Wire representation for types: http://www.npgsql.org/dev/types.html
  var oid = pqftype(res, int32(col))
  ## The integer returned is the internal OID number of the type
  case oid
  of 16: return DbType(kind: DbTypeKind.dbBool, name: "bool")
  of 17: return DbType(kind: DbTypeKind.dbBlob, name: "bytea")

  of 21:   return DbType(kind: DbTypeKind.dbInt, name: "int2", size: 2)
  of 23:   return DbType(kind: DbTypeKind.dbInt, name: "int4", size: 4)
  of 20:   return DbType(kind: DbTypeKind.dbInt, name: "int8", size: 8)
  of 1560: return DbType(kind: DbTypeKind.dbBit, name: "bit")
  of 1562: return DbType(kind: DbTypeKind.dbInt, name: "varbit")

  of 18:   return DbType(kind: DbTypeKind.dbFixedChar, name: "char")
  of 19:   return DbType(kind: DbTypeKind.dbFixedChar, name: "name")
  of 1042: return DbType(kind: DbTypeKind.dbFixedChar, name: "bpchar")

  of 25:   return DbType(kind: DbTypeKind.dbVarchar, name: "text")
  of 1043: return DbType(kind: DbTypeKind.dbVarChar, name: "varchar")
  of 2275: return DbType(kind: DbTypeKind.dbVarchar, name: "cstring")

  of 700: return DbType(kind: DbTypeKind.dbFloat, name: "float4")
  of 701: return DbType(kind: DbTypeKind.dbFloat, name: "float8")

  of 790:  return DbType(kind: DbTypeKind.dbDecimal, name: "money")
  of 1700: return DbType(kind: DbTypeKind.dbDecimal, name: "numeric")

  of 704:  return DbType(kind: DbTypeKind.dbTimeInterval, name: "tinterval")
  of 702:  return DbType(kind: DbTypeKind.dbTimestamp, name: "abstime")
  of 703:  return DbType(kind: DbTypeKind.dbTimeInterval, name: "reltime")
  of 1082: return DbType(kind: DbTypeKind.dbDate, name: "date")
  of 1083: return DbType(kind: DbTypeKind.dbTime, name: "time")
  of 1114: return DbType(kind: DbTypeKind.dbTimestamp, name: "timestamp")
  of 1184: return DbType(kind: DbTypeKind.dbTimestamp, name: "timestamptz")
  of 1186: return DbType(kind: DbTypeKind.dbTimeInterval, name: "interval")
  of 1266: return DbType(kind: DbTypeKind.dbTime, name: "timetz")

  of 114:  return DbType(kind: DbTypeKind.dbJson, name: "json")
  of 142:  return DbType(kind: DbTypeKind.dbXml, name: "xml")
  of 3802: return DbType(kind: DbTypeKind.dbJson, name: "jsonb")

  of 600: return DbType(kind: DbTypeKind.dbPoint, name: "point")
  of 601: return DbType(kind: DbTypeKind.dbLseg, name: "lseg")
  of 602: return DbType(kind: DbTypeKind.dbPath, name: "path")
  of 603: return DbType(kind: DbTypeKind.dbBox, name: "box")
  of 604: return DbType(kind: DbTypeKind.dbPolygon, name: "polygon")
  of 628: return DbType(kind: DbTypeKind.dbLine, name: "line")
  of 718: return DbType(kind: DbTypeKind.dbCircle, name: "circle")

  of 650: return DbType(kind: DbTypeKind.dbInet, name: "cidr")
  of 829: return DbType(kind: DbTypeKind.dbMacAddress, name: "macaddr")
  of 869: return DbType(kind: DbTypeKind.dbInet, name: "inet")

  of 2950: return DbType(kind: DbTypeKind.dbVarchar, name: "uuid")
  of 3614: return DbType(kind: DbTypeKind.dbVarchar, name: "tsvector")
  of 3615: return DbType(kind: DbTypeKind.dbVarchar, name: "tsquery")
  of 2970: return DbType(kind: DbTypeKind.dbVarchar, name: "txid_snapshot")

  of 27:   return DbType(kind: DbTypeKind.dbComposite, name: "tid")
  of 1790: return DbType(kind: DbTypeKind.dbComposite, name: "refcursor")
  of 2249: return DbType(kind: DbTypeKind.dbComposite, name: "record")
  of 3904: return DbType(kind: DbTypeKind.dbComposite, name: "int4range")
  of 3906: return DbType(kind: DbTypeKind.dbComposite, name: "numrange")
  of 3908: return DbType(kind: DbTypeKind.dbComposite, name: "tsrange")
  of 3910: return DbType(kind: DbTypeKind.dbComposite, name: "tstzrange")
  of 3912: return DbType(kind: DbTypeKind.dbComposite, name: "daterange")
  of 3926: return DbType(kind: DbTypeKind.dbComposite, name: "int8range")

  of 22:   return DbType(kind: DbTypeKind.dbArray, name: "int2vector")
  of 30:   return DbType(kind: DbTypeKind.dbArray, name: "oidvector")
  of 143:  return DbType(kind: DbTypeKind.dbArray, name: "xml[]")
  of 199:  return DbType(kind: DbTypeKind.dbArray, name: "json[]")
  of 629:  return DbType(kind: DbTypeKind.dbArray, name: "line[]")
  of 651:  return DbType(kind: DbTypeKind.dbArray, name: "cidr[]")
  of 719:  return DbType(kind: DbTypeKind.dbArray, name: "circle[]")
  of 791:  return DbType(kind: DbTypeKind.dbArray, name: "money[]")
  of 1000: return DbType(kind: DbTypeKind.dbArray, name: "bool[]")
  of 1001: return DbType(kind: DbTypeKind.dbArray, name: "bytea[]")
  of 1002: return DbType(kind: DbTypeKind.dbArray, name: "char[]")
  of 1003: return DbType(kind: DbTypeKind.dbArray, name: "name[]")
  of 1005: return DbType(kind: DbTypeKind.dbArray, name: "int2[]")
  of 1006: return DbType(kind: DbTypeKind.dbArray, name: "int2vector[]")
  of 1007: return DbType(kind: DbTypeKind.dbArray, name: "int4[]")
  of 1008: return DbType(kind: DbTypeKind.dbArray, name: "regproc[]")
  of 1009: return DbType(kind: DbTypeKind.dbArray, name: "text[]")
  of 1028: return DbType(kind: DbTypeKind.dbArray, name: "oid[]")
  of 1010: return DbType(kind: DbTypeKind.dbArray, name: "tid[]")
  of 1011: return DbType(kind: DbTypeKind.dbArray, name: "xid[]")
  of 1012: return DbType(kind: DbTypeKind.dbArray, name: "cid[]")
  of 1013: return DbType(kind: DbTypeKind.dbArray, name: "oidvector[]")
  of 1014: return DbType(kind: DbTypeKind.dbArray, name: "bpchar[]")
  of 1015: return DbType(kind: DbTypeKind.dbArray, name: "varchar[]")
  of 1016: return DbType(kind: DbTypeKind.dbArray, name: "int8[]")
  of 1017: return DbType(kind: DbTypeKind.dbArray, name: "point[]")
  of 1018: return DbType(kind: DbTypeKind.dbArray, name: "lseg[]")
  of 1019: return DbType(kind: DbTypeKind.dbArray, name: "path[]")
  of 1020: return DbType(kind: DbTypeKind.dbArray, name: "box[]")
  of 1021: return DbType(kind: DbTypeKind.dbArray, name: "float4[]")
  of 1022: return DbType(kind: DbTypeKind.dbArray, name: "float8[]")
  of 1023: return DbType(kind: DbTypeKind.dbArray, name: "abstime[]")
  of 1024: return DbType(kind: DbTypeKind.dbArray, name: "reltime[]")
  of 1025: return DbType(kind: DbTypeKind.dbArray, name: "tinterval[]")
  of 1027: return DbType(kind: DbTypeKind.dbArray, name: "polygon[]")
  of 1040: return DbType(kind: DbTypeKind.dbArray, name: "macaddr[]")
  of 1041: return DbType(kind: DbTypeKind.dbArray, name: "inet[]")
  of 1263: return DbType(kind: DbTypeKind.dbArray, name: "cstring[]")
  of 1115: return DbType(kind: DbTypeKind.dbArray, name: "timestamp[]")
  of 1182: return DbType(kind: DbTypeKind.dbArray, name: "date[]")
  of 1183: return DbType(kind: DbTypeKind.dbArray, name: "time[]")
  of 1185: return DbType(kind: DbTypeKind.dbArray, name: "timestamptz[]")
  of 1187: return DbType(kind: DbTypeKind.dbArray, name: "interval[]")
  of 1231: return DbType(kind: DbTypeKind.dbArray, name: "numeric[]")
  of 1270: return DbType(kind: DbTypeKind.dbArray, name: "timetz[]")
  of 1561: return DbType(kind: DbTypeKind.dbArray, name: "bit[]")
  of 1563: return DbType(kind: DbTypeKind.dbArray, name: "varbit[]")
  of 2201: return DbType(kind: DbTypeKind.dbArray, name: "refcursor[]")
  of 2951: return DbType(kind: DbTypeKind.dbArray, name: "uuid[]")
  of 3643: return DbType(kind: DbTypeKind.dbArray, name: "tsvector[]")
  of 3645: return DbType(kind: DbTypeKind.dbArray, name: "tsquery[]")
  of 3807: return DbType(kind: DbTypeKind.dbArray, name: "jsonb[]")
  of 2949: return DbType(kind: DbTypeKind.dbArray, name: "txid_snapshot[]")
  of 3905: return DbType(kind: DbTypeKind.dbArray, name: "int4range[]")
  of 3907: return DbType(kind: DbTypeKind.dbArray, name: "numrange[]")
  of 3909: return DbType(kind: DbTypeKind.dbArray, name: "tsrange[]")
  of 3911: return DbType(kind: DbTypeKind.dbArray, name: "tstzrange[]")
  of 3913: return DbType(kind: DbTypeKind.dbArray, name: "daterange[]")
  of 3927: return DbType(kind: DbTypeKind.dbArray, name: "int8range[]")
  of 2287: return DbType(kind: DbTypeKind.dbArray, name: "record[]")

  of 705:  return DbType(kind: DbTypeKind.dbUnknown, name: "unknown")
  else: return DbType(kind: DbTypeKind.dbUnknown, name: $oid) ## Query the system table pg_type to determine exactly which type is referenced.

proc setColumnInfo(columns: var DbColumns; res: PPGresult; L: int32) =
  setLen(columns, L)
  for i in 0'i32..<L:
    columns[i].name = $pqfname(res, i)
    columns[i].typ = getColumnType(res, i)
    columns[i].tableName = $(pqftable(res, i)) ## Returns the OID of the table from which the given column was fetched.
                                               ## Query the system table pg_class to determine exactly which table is referenced.
    #columns[i].primaryKey = libpq does not have a function for that
    #columns[i].foreignKey = libpq does not have a function for that

iterator instantRows*(db: DbConn; columns: var DbColumns; query: SqlQuery;
                      args: varargs[string, `$`]): InstantRow
                      {.old, tags: [ReadDbEffect].} =
  var res = setupQuery(db, query, args)
  setColumnInfo(columns, res, pqnfields(res))
  for i in 0'i32..<pqntuples(res):
    yield InstantRow(res: res, line: i)
  pqClear(res)

proc `[]`*(row: InstantRow; col: int): string {.old, inline.} =
  ## returns text for given column of the row
  $pqgetvalue(row.res, int32(row.line), int32(col))

proc unsafeColumnAt*(row: InstantRow, index: int): cstring {.old, inline.} =
  ## Return cstring of given column of the row
  pqgetvalue(row.res, int32(row.line), int32(index))

proc len*(row: InstantRow): int {.old, inline.} =
  ## returns number of columns in the row
  int(pqNfields(row.res))

# Common
proc getRow*(db: DbConn, query: SqlQuery,
             args: varargs[DbValue, dbValue]): Option[Row]
             {.tags: [ReadDbEffect].} =
  ## Retrieves a single row.
  for row in db.rows(query, args):
    return row.some

proc getRow*(db: DbConn, stmtName: SqlPrepared,
             args: varargs[string, `$`]): RowOld {.old, tags: [ReadDbEffect].} =
  var res = setupQuery(db, stmtName, args)
  var L = pqNfields(res)
  result = newRow(L)
  if pqntuples(res) > 0:
    setRow(res, result, 0, L)
  pqClear(res)

# Common
proc getAllRows*(db: DbConn, query: SqlQuery,
                 args: varargs[DbValue, dbValue]): seq[Row]
                 {.tags: [ReadDbEffect].} =
  ## Executes the query and returns the whole result dataset.
  result = @[]
  for r in db.rows(query, args):
    result.add(r)

proc getAllRows*(db: DbConn, stmtName: SqlPrepared,
                 args: varargs[string, `$`]): seq[RowOld] {.old, tags:
                 [ReadDbEffect].} =
  ## executes the prepared query and returns the whole result dataset.
  result = @[]
  for r in fastRows(db, stmtName, args):
    result.add(r)

iterator rows*(db: DbConn, stmtName: SqlPrepared,
               args: varargs[string, `$`]): RowOld {.old, tags: [ReadDbEffect].} =
  ## same as `fastRows`, but slower and safe.
  for r in items(getAllRows(db, stmtName, args)): yield r

proc getValue*(db: DbConn, query: SqlQuery,
               args: varargs[string, `$`]): string {.old,
               tags: [ReadDbEffect].} =
  ## executes the query and returns the first column of the first row of the
  ## result dataset. Returns "" if the dataset contains no rows or the database
  ## value is NULL.
  var x = pqgetvalue(setupQuery(db, query, args), 0, 0)
  result = if isNil(x): "" else: $x

proc getValue*(db: DbConn, stmtName: SqlPrepared,
               args: varargs[string, `$`]): string {.old,
               tags: [ReadDbEffect].} =
  ## executes the query and returns the first column of the first row of the
  ## result dataset. Returns "" if the dataset contains no rows or the database
  ## value is NULL.
  var x = pqgetvalue(setupQuery(db, stmtName, args), 0, 0)
  result = if isNil(x): "" else: $x

proc tryInsertID*(db: DbConn, query: SqlQuery,
                  args: varargs[string, `$`]): int64 {.old,
                  tags: [WriteDbEffect].}=
  ## executes the query (typically "INSERT") and returns the
  ## generated ID for the row or -1 in case of an error. For Postgre this adds
  ## ``RETURNING id`` to the query, so it only works if your primary key is
  ## named ``id``.
  var x = pqgetvalue(setupQuery(db, SqlQuery(string(query) & " RETURNING id"),
    args), 0, 0)
  if not isNil(x):
    result = parseBiggestInt($x)
  else:
    result = -1

proc insertID*(db: DbConn, query: SqlQuery,
               args: varargs[DbValue, dbValue]): int64 {.
               tags: [WriteDbEffect].} =
  ## executes the query (typically "INSERT") and returns the
  ## generated ID for the row. For Postgre this adds
  ## ``RETURNING id`` to the query, so it only works if your primary key is
  ## named ``id``.
  let query1 = SqlQuery(string(query) & " RETURNING id")
  db.withStmt(query1, args):
    if pqNfields(res) != 1 or pqntuples(res) != 1 or pqgetisnull(res, 0, 0) != 0:
      dbError("insertID: unexpected result")
    return parseBiggestInt($pqgetvalue(res, 0, 0))

proc execAffectedRows*(db: DbConn, query: SqlQuery,
                       args: varargs[string, `$`]): int64 {.old, tags: [
                       ReadDbEffect, WriteDbEffect].} =
  ## executes the query (typically "UPDATE") and returns the
  ## number of affected rows.
  var q = dbFormat(query, args)
  var res = pqExec(db, q)
  if pqresultStatus(res) != PGRES_COMMAND_OK: dbError(db)
  result = parseBiggestInt($pqcmdTuples(res))
  pqclear(res)

proc execAffectedRows*(db: DbConn, stmtName: SqlPrepared,
                       args: varargs[string, `$`]): int64 {.old, tags: [
                       ReadDbEffect, WriteDbEffect].} =
  ## executes the query (typically "UPDATE") and returns the
  ## number of affected rows.
  var arr = allocCStringArray(args)
  var res = pqexecPrepared(db, stmtName.string, int32(args.len), arr,
                           nil, nil, 0)
  deallocCStringArray(arr)
  if pqresultStatus(res) != PGRES_COMMAND_OK: dbError(db)
  result = parseBiggestInt($pqcmdTuples(res))
  pqclear(res)

proc close*(db: DbConn) {.tags: [DbEffect].} =
  ## closes the database connection.
  if db != nil: pqfinish(db)

proc open*(connection, user, password, database: string): DbConn {.
  tags: [DbEffect].} =
  ## opens a database connection. Raises `EDb` if the connection could not
  ## be established.
  ##
  ## Clients can also use Postgres keyword/value connection strings to
  ## connect.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##      con = open("", "", "", "host=localhost port=5432 dbname=mydb")
  ##
  ## See http://www.postgresql.org/docs/current/static/libpq-connect.html#LIBPQ-CONNSTRING
  ## for more information.
  let
    colonPos = connection.find(':')
    host = if colonPos < 0: connection
           else: substr(connection, 0, colonPos-1)
    port = if colonPos < 0: ""
           else: substr(connection, colonPos+1)
  result = pqsetdbLogin(host, port, nil, nil, database, user, password)
  if pqStatus(result) != CONNECTION_OK: dbError(result) # result = nil

proc setEncoding*(connection: DbConn, encoding: string): bool {.
  tags: [DbEffect].} =
  ## sets the encoding of a database connection, returns true for
  ## success, false for failure.
  return pqsetClientEncoding(connection, encoding) == 0
