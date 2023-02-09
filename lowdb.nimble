version       = "0.1.0"
author        = "Albert Safin <xzfcpw@gmail.com>" # Original Author of the package
description   = "Low level db_sqlite and db_postgres forks with a proper typing"
license       = "MIT"

requires "nim >= 0.19.0"
when NimMajor >= 1 and NimMinor >= 9:
  requires "db_connector >= 0.1.0"

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

task docs, "Generate docs":
  rmDir "docs/apidocs"
  exec "nimble doc --outdir:docs/apidocs --project --index:on lowdb/sqlite.nim"