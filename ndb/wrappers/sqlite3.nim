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
