## Bindings that are not in ``std/sqlite3`` yet.

{.deadCodeElim: on.}  # dce option deprecated
when defined(windows):
  when defined(nimOldDlls):
    const Lib = "sqlite3.dll"
  elif defined(cpu64):
    const Lib = "sqlite3_64.dll"
  else:
    const Lib = "sqlite3_32.dll"
elif defined(macosx):
  const
    Lib = "libsqlite3(|.0).dylib"
else:
  const
    Lib = "libsqlite3.so(|.0)"

import std/sqlite3
export sqlite3

proc db_handle*(para1: Pstmt): PSqlite3 {.cdecl, dynlib: Lib, importc: "sqlite3_db_handle".}

# open_v2 consts
const 
  SQLITE_OPEN_READONLY* =        0x00000001.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_READWRITE* =       0x00000002.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_CREATE* =          0x00000004.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_DELETEONCLOSE* =   0x00000008.int    #/* VFS only */
  SQLITE_OPEN_EXCLUSIVE* =       0x00000010.int    #/* VFS only */
  SQLITE_OPEN_AUTOPROXY* =       0x00000020.int    #/* VFS only */
  SQLITE_OPEN_URI* =             0x00000040.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_MEMORY* =          0x00000080.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_MAIN_DB* =         0x00000100.int    #/* VFS only */
  SQLITE_OPEN_TEMP_DB* =         0x00000200.int    #/* VFS only */
  SQLITE_OPEN_TRANSIENT_DB* =    0x00000400.int    #/* VFS only */
  SQLITE_OPEN_MAIN_JOURNAL* =    0x00000800.int    #/* VFS only */
  SQLITE_OPEN_TEMP_JOURNAL* =    0x00001000.int    #/* VFS only */
  SQLITE_OPEN_SUBJOURNAL* =      0x00002000.int    #/* VFS only */
  SQLITE_OPEN_MASTER_JOURNAL* =  0x00004000.int    #/* VFS only */
  SQLITE_OPEN_NOMUTEX* =         0x00008000.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_FULLMUTEX* =       0x00010000.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_SHAREDCACHE* =     0x00020000.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_PRIVATECACHE* =    0x00040000.int  #/* Ok for sqlite3_open_v2() */
  SQLITE_OPEN_WAL* =             0x00080000.int    #/* VFS only */

proc sqlite3_open_v2*(filename: cstring, ppDb : var PSqlite3, 
                      flags : int32 , zVfsName : cstring ) : int32{.
                        cdecl,dynlib: Lib,importc: "sqlite3_open_v2".}

proc sqlite3_db_readonly*(ppDb : var PSqlite3, dbname : cstring) : int32{.
                        cdecl,dynlib: Lib,importc: "sqlite3_db_readonly".}
## returns 1 if the specified db is in readonly mode
