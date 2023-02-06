## EXTRA: CONNECTING TO MULTIPLE DATABASES

It is possible to connect to multiple databases, even databases of different kinds. Simply import libraries with aliases to prevent name collision. You can also directly import a "db_common" library to use the shared database types between both libraries.

For example:

```nim
import ndb / dbtypes
import ndb / sqlite as s
import ndb / postgresql as p

let sdb = s.open("example.db", "", "", "")
let pdb = p.open("localhost", "MyDB", "sammy", "sammy")

# [TODO] more here

sdb.close()
pdb.close()
```

### BACK TO DOC
[return to main document](How-To-Use-NDB.md#connecting)
