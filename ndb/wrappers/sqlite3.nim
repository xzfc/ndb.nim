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

# regarding the online backup_api please take a look at
# www.sqlite.org/backup.html
type
  Sqlite3Backup* {.pure , final .} = object 
  PSqlite3Backup* = ptr Sqlite3Backup

proc sqlite3_backup_init*( destDb :  PSqlite3, destDbName : cstring,
                          srcDb : PSqlite3, srcDbName : cstring) :  PSqlite3Backup{.
                importc: "sqlite3_backup_init", cdecl, dynlib: Lib.}
proc sqlite3_backup_step*(p : pointer, nPage : int) : int{.
                importc: "sqlite3_backup_step", cdecl, dynlib: Lib.}
proc sqlite3_backup_remaining*(p : var PSqlite3Backup) : int {.
                importc: "sqlite3_backup_remaining", cdecl, dynlib: Lib.}
proc sqlite3_backup_pagecount*(p : var PSqlite3Backup) : int {.
                importc: "sqlite3_backup_pagecount", cdecl, dynlib: Lib.}
proc sqlite3_backup_finish*(p : pointer) : int {.
                importc: "sqlite3_backup_finish", cdecl, dynlib: Lib.}
proc sqlite3_extended_result_codes* : int {.
                importc: "sqlite3_extended_result_codes", cdecl, dynlib: Lib.}
proc sqlite3_extended_errcode*: int {.
                importc: "sqlite3_extended_errcode", cdecl, dynlib: Lib.}
