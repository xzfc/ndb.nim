version       = "0.19.8"
author        = "Albert Safin <xzfcpw@gmail.com>"
description   = "A db_sqlite fork with a proper typing"
license       = "MIT"

requires "nim >= 0.19.0"

skipDirs = @["tests"]

task test_sqlite, "Run the test suite (sqlite)":
  exec "nim c -r tests/tsqlite.nim"

task test_postgres, "Run the test suite (postgres)":
  exec "nim c -r tests/tpostgres.nim"

task test, "Run the test suite (all)":
  testSqliteTask()
  testPostgresTask()

task benchmark, "Compile the benchmark":
  exec "nim c -d:mode=0 -d:release -o:tests/bsqlite.0 tests/bsqlite.nim"
  exec "nim c -d:mode=1 -d:release -o:tests/bsqlite.1 tests/bsqlite.nim"
