version       = "0.19.0"
author        = "Albert Safin <xzfcpw@gmail.com>"
description   = "A db_sqlite fork with a proper typing"
license       = "MIT"

requires "nim >= 0.17.0"

skipDirs = @["tests"]

task test, "Runs the test suite":
  exec "nim c -r tests/tsqlite.nim"
