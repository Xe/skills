---
name: gorm-dao
description: Write GORM data access code using the DAO (Data Access Object) pattern. Use when creating database models, writing queries, setting up GORM, adding CRUD methods, or working with gorm.io in Go services. Also use when the user mentions "DAO", "data access", "ORM", "database models", "GORM", or is building a Go service that talks to a relational database.
---

# GORM with the DAO Pattern

This skill guides writing Go data access layers using GORM (gorm.io) organized around the DAO pattern. All database operations go through a single DAO struct, with methods grouped into per-entity files. This keeps callers free from direct database concerns while keeping each file focused.

## When to read reference files

This skill includes detailed GORM reference docs in `references/`. Read them when you need specifics:

- **`references/gorm-basics.md`** -- Models, struct tags, conventions, CRUD operations, connecting to databases. Read when defining new models or writing basic queries.
- **`references/gorm-associations.md`** -- Belongs-to, has-one, has-many, many-to-many, preloading, association mode. Read when defining relationships between models or loading related data.
- **`references/gorm-advanced.md`** -- Scopes, transactions, hooks, migrations, performance tuning, error handling, raw SQL, custom data types. Read when writing complex queries, transactions, or optimizing performance.
- **`references/sqlite-wasm.md`** -- The ncruces/go-sqlite3 pure-WASM driver and its gormlite dialect. Read when working with SQLite in Go without CGO. This driver is optional -- not every project needs it.

## Database choice

Services in this repo generally use **PostgreSQL** for production databases. The `mi` service is an exception that uses **SQLite** because it is a small, self-contained personal service where an embedded database makes sense. When creating a new service, default to Postgres unless there is a specific reason to use SQLite (single-user, embedded, no external DB dependency needed).

## The DAO pattern

The DAO struct owns the `*gorm.DB` connection and exposes domain-specific methods. This keeps database logic contained -- callers never construct raw queries.

### Structure

```go
package models

import (
    "context"
    "errors"

    "gorm.io/gorm"
)

// Domain-specific errors live in the package.
var ErrNotFound = errors.New("models: not found")

// DAO holds the database connection and all data access methods.
type DAO struct {
    db *gorm.DB
}

// New creates a DAO, runs migrations, and configures plugins.
func New(dialector gorm.Dialector) (*DAO, error) {
    db, err := gorm.Open(dialector, &gorm.Config{})
    if err != nil {
        return nil, err
    }

    // AutoMigrate creates tables, adds missing columns/indexes.
    // It will NOT delete unused columns (safe by design).
    if err := db.AutoMigrate(&User{}, &Order{}, &Product{}); err != nil {
        return nil, err
    }

    return &DAO{db: db}, nil
}

// DB exposes the underlying *gorm.DB as an escape hatch.
// Prefer adding methods to DAO over using this directly.
func (d *DAO) DB() *gorm.DB {
    return d.db
}
```

### Key principles

1. **Every method takes `context.Context` as its first parameter** and applies it with `.WithContext(ctx)`. This enables cancellation, timeouts, and tracing to flow through.

2. **Methods are named for what they do in domain terms**, not SQL terms. `ActiveSubscription()` instead of `SelectLatestSubscription()`. `HasProduct()` instead of `CountProductsBySKU()`.

3. **Return domain errors**, not raw GORM errors, when it makes the caller's life easier. Wrap or translate `gorm.ErrRecordNotFound` into your own sentinel error if it is a normal case (not exceptional).

4. **The DAO constructor runs AutoMigrate.** This keeps schema in sync with struct definitions automatically. For production services with complex migration needs, consider a dedicated migration tool instead.

5. **Expose `DB()` for escape hatches** but prefer adding DAO methods. Direct DB access should be rare.

6. **Group DAO methods by entity file.** Methods that operate on a model belong in that model's file, not in `dao.go`. For example, `CreateUser` and `ListUsers` go in `user.go` alongside the `User` struct. `dao.go` holds only the `DAO` struct, constructor, `DB()`, `Ping()`, and other infrastructure that is not tied to a specific entity. This keeps each file focused and easy to navigate as the number of models grows.

## Model definition

```go
// In user.go -- simple model, no gorm.Model needed
type User struct {
    ID    int    `gorm:"primaryKey"`
    Name  string `gorm:"uniqueIndex"`
    Email string
    Bio   *string // pointer = nullable
}

// In order.go -- embeds gorm.Model for timestamps and soft delete
type Order struct {
    gorm.Model                        // adds ID, CreatedAt, UpdatedAt, DeletedAt
    ID       string    `gorm:"uniqueIndex"` // override with string ID (e.g. ULID)
    Total    int
    UserID   int
    User     User      `gorm:"foreignKey:UserID"` // relationship
}
```

### When to embed `gorm.Model`

Embed `gorm.Model` when you want automatic `CreatedAt`, `UpdatedAt`, and soft-delete (`DeletedAt`) tracking. Skip it when the model is simple and does not need those fields -- just define `ID` yourself.

### ID strategies

- **Auto-increment integers**: Default for `uint`/`int` primary keys. Simple, good for most cases.
- **ULIDs or UUIDs as strings**: Use `gorm:"uniqueIndex"` on a string `ID` field. Generate in a `BeforeCreate` hook or in the DAO method. ULIDs sort chronologically, which is useful for time-ordered data.

### Struct tags quick reference

| Tag | Purpose |
|-----|---------|
| `gorm:"primaryKey"` | Explicit primary key |
| `gorm:"uniqueIndex"` | Unique index (enforces uniqueness at DB level) |
| `gorm:"index"` | Regular index for WHERE/ORDER performance |
| `gorm:"foreignKey:FieldName"` | Explicit foreign key for associations |
| `gorm:"column:col_name"` | Override column name |
| `gorm:"type:varchar(100)"` | Override column type |
| `gorm:"default:value"` | Default value |
| `gorm:"not null"` | NOT NULL constraint |
| `gorm:"-"` | Ignore field entirely |

See `references/gorm-basics.md` for the full tag reference.

## File organization

```
models/
  dao.go       -- DAO struct, New(), DB(), Ping(), infrastructure
  user.go      -- User model + DAO methods: CreateUser(), GetUser(), ListUsers()
  order.go     -- Order model + DAO methods: CreateOrder(), GetOrder(), UserOrders()
  product.go   -- Product model + DAO methods: GetProduct(), ListProducts(), HasProduct()
```

Each entity file contains both the struct definition and every DAO method that operates on that entity. `dao.go` is kept lean -- just the connection, constructor, and helpers that do not belong to any single entity.

## Query patterns

### Always use context

```go
// In user.go, alongside the User struct definition
func (d *DAO) GetUser(ctx context.Context, id int) (*User, error) {
    var user User
    if err := d.db.WithContext(ctx).First(&user, id).Error; err != nil {
        return nil, err
    }
    return &user, nil
}
```

### Loading associations

Use `.Joins()` for eager loading in a single query (belongs-to/has-one):

```go
// In order.go
func (d *DAO) GetOrder(ctx context.Context, id string) (*Order, error) {
    var order Order
    err := d.db.WithContext(ctx).
        Joins("User").
        Where("orders.id = ?", id).
        First(&order).Error
    return &order, err
}
```

Use `.Preload()` for has-many or when you need separate queries:

```go
// In user.go
func (d *DAO) GetUserWithOrders(ctx context.Context, id int) (*User, error) {
    var user User
    err := d.db.WithContext(ctx).
        Preload("Orders", func(db *gorm.DB) *gorm.DB {
            return db.Order("created_at DESC")
        }).
        First(&user, id).Error
    return &user, err
}
```

### Pagination

```go
// In order.go
func (d *DAO) ListOrders(ctx context.Context, count, page int) ([]Order, error) {
    var orders []Order
    err := d.db.WithContext(ctx).
        Joins("User").
        Order("created_at DESC").
        Limit(count).
        Offset(count * page).
        Find(&orders).Error
    return orders, err
}
```

### Existence checks

```go
// In product.go
func (d *DAO) HasProduct(ctx context.Context, sku string) (bool, error) {
    var count int64
    err := d.db.WithContext(ctx).
        Model(&Product{}).
        Where("sku = ?", sku).
        Count(&count).Error
    return count > 0, err
}
```

### Transactions

Use transactions when multiple operations must succeed or fail together:

```go
// In order.go -- transferring an order between users
func (d *DAO) TransferOrder(ctx context.Context, orderID string, newUserID int) error {
    tx := d.db.Begin()

    var order Order
    if err := tx.WithContext(ctx).
        Where("id = ?", orderID).
        First(&order).Error; err != nil {
        tx.Rollback()
        return err
    }

    order.UserID = newUserID
    if err := tx.WithContext(ctx).Save(&order).Error; err != nil {
        tx.Rollback()
        return err
    }

    if err := tx.Commit().Error; err != nil {
        return err
    }

    return nil
}
```

For simpler cases, use the closure form which auto-commits/rollbacks:

```go
err := d.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&record1).Error; err != nil {
        return err // triggers rollback
    }
    if err := tx.Create(&record2).Error; err != nil {
        return err
    }
    return nil // triggers commit
})
```

## Observability

Set up structured logging and metrics in the constructor:

```go
import (
    slogGorm "github.com/orandin/slog-gorm"
    gormPrometheus "gorm.io/plugin/prometheus"
)

func New(dialector gorm.Dialector) (*DAO, error) {
    db, err := gorm.Open(dialector, &gorm.Config{
        Logger: slogGorm.New(
            slogGorm.WithErrorField("err"),
            slogGorm.WithRecordNotFoundError(),
        ),
    })
    if err != nil {
        return nil, err
    }

    db.Use(gormPrometheus.New(gormPrometheus.Config{
        DBName: "myservice",
    }))

    // ... AutoMigrate, etc.
}
```

## Protobuf conversion

When models need to be served over gRPC or serialized to protobuf, add `AsProto()` methods to models rather than mixing protobuf tags into GORM structs. This keeps the database layer clean:

```go
// In user.go, alongside the User struct
func (u *User) AsProto() *pb.User {
    return &pb.User{
        Id:    int64(u.ID),
        Name:  u.Name,
        Email: u.Email,
    }
}
```

## Connecting to databases

### PostgreSQL (default for services)

```go
import "gorm.io/driver/postgres"

dsn := "host=localhost user=myapp password=secret dbname=myapp port=5432 sslmode=disable"
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
```

### SQLite (for embedded/single-user services)

With the standard CGO driver:
```go
import "gorm.io/driver/sqlite"

db, err := gorm.Open(sqlite.Open("myapp.db"), &gorm.Config{})
```

With the pure-WASM driver (no CGO required -- see `references/sqlite-wasm.md`):
```go
import "github.com/ncruces/go-sqlite3/gormlite"

db, err := gorm.Open(gormlite.Open("myapp.db"), &gorm.Config{})
```

## Testing

DAO methods are straightforward to test with a real database. Use SQLite in-memory for fast tests even if production uses Postgres:

```go
func setupTestDAO(t *testing.T) *DAO {
    t.Helper()
    dao, err := New(sqlite.Open(":memory:"))
    if err != nil {
        t.Fatal(err)
    }
    return dao
}
```

Use table-driven tests for query methods. See the `go-table-driven-tests` skill for patterns.