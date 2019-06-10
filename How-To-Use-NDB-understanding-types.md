# HOW-TO-USE-NDB

## EXTRA: UNDERSTANDING TYPES

The following are the types currently supported by `ndb`:

| function    | nim type  | SQLite  | PostgreSQL  | MariaDB (mysql) | LEGACY     | refs |
|-------------|-----------|---------|-------------|-----------------|------------|-----------------------------------------------------------------------|
| dbString    | string    | STRING  | TEXT        | TEXT            | dvkString  | |
| dbInt       | int64     | INT     | INT         | INT             | dvkInt     | |
| dbFloat     | float     | DECIMAL | NUMERIC     | DECIMAL         | dvkFloat   | |
| dbBool      | bool      | INT     | BOOL        | BOOL            | dvkBool    | [SQLite bool](https://www.sqlite.org/datatype3.html#boolean_datatype) |
| dbBlob      | (n/a)     | BLOB    | x           | BLOB            | dvkBlob    | }
| dbNull      | (n/a)     | NULL    | NULL        | NULL            | dvkNull    | |
| dbDatetime  | timestamp | INT     | TIMESTAMP   | TIMESTAMP       |            | [nim times std lib](https://nim-lang.org/docs/times.html) |
| dbTimestamp | timestamp | INT     | TIMESTAMP   | TIMESTAMP       |            | |
| dbOid       | Oid       | STRING  | VARCHAR(24) | VARCHAR(24)     |            | [nim Oid std lib](https://nim-lang.org/docs/oids.html) |
| dbUuid      | string    | STRING  | UUID        | VARCHAR(32)     |            | |


### BACK TO DOC
[return to main document](How-To-Use-NDB.md)
