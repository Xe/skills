# Pure-WASM SQLite for Go (ncruces/go-sqlite3)

An alternative SQLite driver for Go that requires no CGO. The `mi` service in this repo uses it, but it is not required for all projects -- choose it when you need SQLite without a C compiler dependency.

## How it works

SQLite's C source is compiled to WebAssembly, then translated to pure Go via [wasm2go](https://github.com/ncruces/wasm2go). At runtime, no Wasm interpreter is needed -- it runs as native Go code. The SQLite VFS (file I/O, locking) is reimplemented in pure Go.

## Comparison with alternatives

|                   | ncruces/go-sqlite3             | mattn/go-sqlite3        | modernc.org/sqlite       |
| ----------------- | ------------------------------ | ----------------------- | ------------------------ |
| CGO required      | No                             | Yes                     | No                       |
| Approach          | C -> Wasm -> Go                | CGO bindings            | C -> Go (transpiler)     |
| Cross-compilation | Trivial                        | Needs cross C toolchain | Possible, large binaries |
| Memory            | Higher (Wasm sandbox per conn) | Lowest                  | Moderate                 |
| Performance       | Competitive                    | Fastest (native C)      | Competitive              |
| Sandboxing        | Yes (Wasm isolation)           | No                      | No                       |

## Import paths

| Package                                      | Purpose                             |
| -------------------------------------------- | ----------------------------------- |
| `github.com/ncruces/go-sqlite3`              | Low-level SQLite API                |
| `github.com/ncruces/go-sqlite3/driver`       | `database/sql` driver               |
| `github.com/ncruces/go-sqlite3/gormlite`     | GORM dialect                        |
| `github.com/ncruces/go-sqlite3/vfs`          | Pure Go VFS                         |
| `github.com/ncruces/go-sqlite3/ext/*`        | Extensions (unicode, stats, blobio) |
| `github.com/ncruces/go-sqlite3/vfs/adiantum` | Encryption at rest (Adiantum)       |
| `github.com/ncruces/go-sqlite3/vfs/xts`      | Encryption at rest (XTS)            |

## GORM integration (gormlite)

```go
import (
    "github.com/ncruces/go-sqlite3/gormlite"
    "gorm.io/gorm"
)

db, err := gorm.Open(gormlite.Open("myapp.db"), &gorm.Config{})
```

Two entry points:

- `gormlite.Open(dsn string) gorm.Dialector` -- open from DSN/file path
- `gormlite.OpenDB(pool gorm.ConnPool) gorm.Dialector` -- open from existing `*sql.DB`

In-memory: `gormlite.Open("file::memory:?cache=shared")`

### What gormlite handles

- Registers as dialect `"sqlite"`
- Maps Go types: bool -> numeric, int/uint -> integer, float -> real, string -> text, time -> datetime, bytes -> blob
- Auto-increment: `integer PRIMARY KEY AUTOINCREMENT`
- Nested transactions via SAVEPOINT/ROLLBACK TO
- Silently drops FOR UPDATE/FOR SHARE (SQLite has no row-level locking)
- Full migration support (DDL, column parsing)

## database/sql usage (without GORM)

```go
import (
    "database/sql"
    _ "github.com/ncruces/go-sqlite3/driver"
)

db, err := sql.Open("sqlite3", "file:demo.db")
```

URI format supports inline pragmas:

```
"file:demo.db?_pragma=busy_timeout(10000)&_pragma=journal_mode(WAL)"
```

## Backup API

One-shot backup:

```go
err := srcConn.Backup("main", "file:backup.db")
```

Incremental backup with progress:

```go
backup, err := src.BackupInit("main", "file:backup.db")
defer backup.Close()

for {
    done, err := backup.Step(100)  // copy 100 pages at a time
    if done {
        break
    }
}
```

The `mi` service uses this for periodic database backups.

## Platform support

Tested across Linux (amd64, arm64, 386, arm, riscv64, ppc64le, loong64, s390x), macOS (amd64, arm64), Windows (amd64, arm64), FreeBSD, NetBSD, DragonFly BSD, OpenBSD, illumos, and Solaris.

## Gotchas

### File locking

- Linux/macOS: Uses OFD locks (correct behavior, requires Linux 3.15+)
- FreeBSD/illumos: Falls back to BSD locks with reduced concurrency (BEGIN IMMEDIATE = BEGIN EXCLUSIVE)
- Unsupported platforms: Must use `nolock=1` or `immutable=1` and `db.SetMaxOpenConns(1)`

### WAL mode

Uses mmap for shared memory on Unix, MapViewOfFile on Windows. On unsupported platforms, WAL requires EXCLUSIVE locking mode and single connection.

### Compatibility

Do not concurrently access the same database file from this driver and a different SQLite implementation using non-default build tags (`sqlite3_flock`, `sqlite3_dotlk`). Default configuration is compatible with standard SQLite tools.

### Pre-v1

Both the main module and gormlite are pre-v1. The API may change between minor versions.

## When to use this vs alternatives

**Use ncruces/go-sqlite3 when:**

- You need cross-compilation without CGO
- You want Wasm sandboxing for connection isolation
- You need the backup API in pure Go
- Your CI/CD does not have a C compiler

**Use mattn/go-sqlite3 when:**

- Maximum performance matters
- CGO is already in your build chain
- You need the smallest binary size

**Use modernc.org/sqlite when:**

- You want pure Go without the Wasm layer
- You need broad architecture support without CGO

**Use PostgreSQL when:**

- You have multiple service instances
- You need concurrent access from many processes
- The service is not self-contained/embedded
