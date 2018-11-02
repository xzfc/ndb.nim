version       = "0.19.3"
author        = "Albert Safin <xzfcpw@gmail.com>"
description   = "A db_sqlite fork with a proper typing"
license       = "MIT"

requires "nim >= 0.18.0"

skipDirs = @["tests"]

task test, "Run the test suite":
  exec "nim c -r tests/tsqlite.nim"

task benchmark, "Compile the benchmark":
  exec "nim c -d:mode=0 -d:release -o:tests/bsqlite.0 tests/bsqlite.nim"
  exec "nim c -d:mode=1 -d:release -o:tests/bsqlite.1 tests/bsqlite.nim"
