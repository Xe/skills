# GORM Advanced Features

## Table of Contents

1. [Scopes](#scopes)
2. [Transactions](#transactions)
3. [Hooks (Lifecycle Callbacks)](#hooks)
4. [Migration](#migration)
5. [Performance](#performance)
6. [Custom Data Types](#custom-data-types)
7. [Serializers](#serializers)
8. [DBResolver (Read/Write Splitting)](#dbresolver)
9. [Composite Primary Keys](#composite-primary-keys)
10. [Generics API](#generics-api)

## Scopes

Scopes are reusable query conditions defined as functions:

```go
func AmountGreaterThan1000(db *gorm.DB) *gorm.DB {
    return db.Where("amount > ?", 1000)
}

func PaidWithCreditCard(db *gorm.DB) *gorm.DB {
    return db.Where("pay_mode_sign = ?", "C")
}

func PaidWithCod(db *gorm.DB) *gorm.DB {
    return db.Where("pay_mode_sign = ?", "COD")
}

db.Scopes(AmountGreaterThan1000, PaidWithCreditCard).Find(&orders)
db.Scopes(AmountGreaterThan1000, PaidWithCod).Find(&orders)
```

### Parameterized scopes

Return a closure when the scope needs parameters:

```go
func Paginate(r *http.Request) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        q := r.URL.Query()
        page, _ := strconv.Atoi(q.Get("page"))
        if page <= 0 {
            page = 1
        }
        pageSize, _ := strconv.Atoi(q.Get("page_size"))
        switch {
        case pageSize > 100:
            pageSize = 100
        case pageSize <= 0:
            pageSize = 10
        }
        offset := (page - 1) * pageSize
        return db.Offset(offset).Limit(pageSize)
    }
}

db.Scopes(Paginate(r)).Find(&users)
```

### Dynamic table scopes

```go
func TableOfYear(year int) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Table(fmt.Sprintf("orders_%d", year))
    }
}

db.Scopes(TableOfYear(2024)).Find(&orders)
```

## Transactions

### Default behavior

GORM wraps every write operation in a transaction automatically. Disable for ~30% performance gain when not needed:

```go
db, err := gorm.Open(sqlite.Open("gorm.db"), &gorm.Config{
    SkipDefaultTransaction: true,
})
```

### Transaction block (recommended)

Auto commits on nil return, rolls back on error return:

```go
db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&Animal{Name: "Giraffe"}).Error; err != nil {
        return err // rollback
    }
    if err := tx.Create(&Animal{Name: "Lion"}).Error; err != nil {
        return err // rollback
    }
    return nil // commit
})
```

### Nested transactions

```go
db.Transaction(func(tx *gorm.DB) error {
    tx.Create(&user1)

    tx.Transaction(func(tx2 *gorm.DB) error {
        tx2.Create(&user2)
        return errors.New("rollback user2") // only rolls back user2
    })

    return nil // commits user1
})
```

### Manual transactions

```go
tx := db.Begin()

if err := tx.Create(&Animal{Name: "Giraffe"}).Error; err != nil {
    tx.Rollback()
    return err
}

if err := tx.Create(&Animal{Name: "Lion"}).Error; err != nil {
    tx.Rollback()
    return err
}

tx.Commit()
```

### SavePoint / RollbackTo

```go
tx := db.Begin()
tx.Create(&user1)

tx.SavePoint("sp1")
tx.Create(&user2)
tx.RollbackTo("sp1") // rolls back user2 only

tx.Commit() // commits user1 only
```

## Hooks

Hooks are methods on your model that run at specific points in the lifecycle. Return an error to abort the operation and trigger rollback.

### Create lifecycle

BeforeSave -> BeforeCreate -> [create] -> AfterCreate -> AfterSave

```go
func (u *User) BeforeCreate(tx *gorm.DB) (err error) {
    u.UUID = uuid.New()
    if !u.IsValid() {
        return errors.New("can't save invalid data")
    }
    return
}

func (u *User) AfterCreate(tx *gorm.DB) (err error) {
    if u.ID == 1 {
        tx.Model(u).Update("role", "admin")
    }
    return
}
```

### Update lifecycle

BeforeSave -> BeforeUpdate -> [update] -> AfterUpdate -> AfterSave

```go
func (u *User) BeforeUpdate(tx *gorm.DB) (err error) {
    if u.readonly() {
        return errors.New("read only user")
    }
    return
}
```

### Delete lifecycle

BeforeDelete -> [delete] -> AfterDelete

### Query lifecycle

[query] -> AfterFind

```go
func (u *User) AfterFind(tx *gorm.DB) (err error) {
    if u.MemberShip == "" {
        u.MemberShip = "user"
    }
    return
}
```

### Skip hooks

```go
db.Session(&gorm.Session{SkipHooks: true}).Create(&user)
```

### Modify current operation in hooks

Access `tx.Statement` to add conditions, select fields, etc.:

```go
func (u *User) BeforeCreate(tx *gorm.DB) error {
    tx.Statement.AddClause(clause.OnConflict{UpdateAll: true})
    return nil
}
```

## Migration

### AutoMigrate

```go
db.AutoMigrate(&User{})
db.AutoMigrate(&User{}, &Product{}, &Order{})

// With table options
db.Set("gorm:table_options", "ENGINE=InnoDB").AutoMigrate(&User{})
```

AutoMigrate creates tables, adds missing columns, adds missing foreign keys, adds missing constraints, and adds missing indexes. It does NOT delete unused columns (data safety).

Disable foreign key creation during migration:

```go
db, err := gorm.Open(sqlite.Open("gorm.db"), &gorm.Config{
    DisableForeignKeyConstraintWhenMigrating: true,
})
```

### Migrator interface

```go
m := db.Migrator()

// Tables
m.CreateTable(&User{})
m.HasTable(&User{})        // or m.HasTable("users")
m.DropTable(&User{})
m.RenameTable(&User{}, &UserInfo{})
m.GetTables()              // list all tables

// Columns
m.AddColumn(&User{}, "Name")
m.DropColumn(&User{}, "Name")
m.AlterColumn(&User{}, "Name")
m.HasColumn(&User{}, "Name")
m.RenameColumn(&User{}, "Name", "NewName")
m.ColumnTypes(&User{})    // returns []gorm.ColumnType

// Indexes
m.CreateIndex(&User{}, "Name")
m.CreateIndex(&User{}, "idx_name")
m.DropIndex(&User{}, "Name")
m.HasIndex(&User{}, "Name")
m.RenameIndex(&User{}, "Name", "Name2")

// Constraints
m.CreateConstraint(&User{}, "fk_users_company")
m.DropConstraint(&User{}, "fk_users_company")
m.HasConstraint(&User{}, "fk_users_company")

// Views
m.CreateView("user_view", gorm.ViewOption{
    Query: db.Model(&User{}).Where("age > ?", 20),
})
```

### Index definitions

```go
type User struct {
    Name  string `gorm:"index"`                              // basic index
    Name2 string `gorm:"index:idx_name,unique"`              // named unique index
    Name3 string `gorm:"index:,sort:desc,collate:utf8,type:btree"` // with options
    Name4 string `gorm:"uniqueIndex"`                        // unique index shorthand
    Age   int64  `gorm:"index:,class:FULLTEXT,comment:hello"` // fulltext
}
```

Composite indexes -- multiple fields sharing the same index name:

```go
type User struct {
    Name   string `gorm:"index:idx_member"`
    Number string `gorm:"index:idx_member"`
}

// Control column order with priority
type User struct {
    Name   string `gorm:"index:idx_member,priority:2"`
    Number string `gorm:"index:idx_member,priority:1"`  // Number first
}
```

Multiple indexes on one field:

```go
type User struct {
    Name string `gorm:"index:idx_name;index:idx_name_2,unique"`
}
```

### Constraints

```go
type User struct {
    Name string `gorm:"check:name_checker,name <> 'jinzhu'"`
}

type User struct {
    CompanyID int
    Company   Company `gorm:"constraint:OnUpdate:CASCADE,OnDelete:SET NULL;"`
}
```

## Performance

### Key optimizations

1. **Disable default transaction**: `SkipDefaultTransaction: true` gives ~30% improvement for single-write operations.

2. **Prepared statement cache**: Reuses parsed SQL plans.

   ```go
   db, err := gorm.Open(sqlite.Open("gorm.db"), &gorm.Config{PrepareStmt: true})
   // or per-session:
   tx := db.Session(&gorm.Session{PrepareStmt: true})
   ```

3. **Select only needed fields**: `db.Select("name", "age").Find(&users)` instead of `SELECT *`.

4. **FindInBatches** for large result sets (avoids loading everything into memory).

5. **Index hints**:

   ```go
   import "gorm.io/hints"
   db.Clauses(hints.UseIndex("idx_user_name")).Find(&User{})
   db.Clauses(hints.ForceIndex("idx_user_name")).Find(&User{})
   ```

6. **Optimizer hints**:
   ```go
   db.Clauses(hints.New("MAX_EXECUTION_TIME(10000)")).Find(&User{})
   ```

### Method chaining

GORM uses an immutable chain pattern. Methods like `Where`, `Select`, `Order` return a new `*gorm.DB` without modifying the original. Finisher methods (`Find`, `First`, `Create`, `Update`, `Delete`) execute the query.

This means you can safely reuse base queries:

```go
base := db.Where("active = ?", true)
admins := base.Where("role = ?", "admin").Find(&adminUsers)
members := base.Where("role = ?", "member").Find(&memberUsers)
```

### Safety

GORM blocks global UPDATE/DELETE (without WHERE) by default, returning `ErrMissingWhereClause`. Override per-session with `AllowGlobalUpdate: true`.

## Custom Data Types

Implement `database/sql` Scanner and driver.Valuer interfaces:

```go
type JSON json.RawMessage

func (j *JSON) Scan(value interface{}) error {
    bytes, ok := value.([]byte)
    if !ok {
        return errors.New("failed to unmarshal JSONB value")
    }
    result := json.RawMessage{}
    err := json.Unmarshal(bytes, &result)
    *j = JSON(result)
    return err
}

func (j JSON) Value() (driver.Value, error) {
    if len(j) == 0 {
        return nil, nil
    }
    return json.RawMessage(j).MarshalJSON()
}
```

### Additional interfaces for custom types

```go
// General type name for plugins/middleware
func (JSON) GormDataType() string { return "json" }

// DB-specific type for migrations
func (JSON) GormDBDataType(db *gorm.DB, field *schema.Field) string {
    switch db.Dialector.Name() {
    case "mysql", "sqlite":
        return "JSON"
    case "postgres":
        return "JSONB"
    }
    return ""
}

// Create from SQL expression
func (JSON) GormValue(ctx context.Context, db *gorm.DB) clause.Expr {
    // ...
}
```

Community data types package: `github.com/go-gorm/datatypes` (JSONQuery, etc.).

## Serializers

Built-in serializers: `json`, `gob`, `unixtime`:

```go
type User struct {
    Roles       []string           `gorm:"serializer:json"`
    Metadata    map[string]any     `gorm:"serializer:json"`
    JobInfo     Job                `gorm:"type:bytes;serializer:gob"`
    CreatedTime int64              `gorm:"serializer:unixtime;type:time"`
}
```

### Custom serializer

Implement `Scan(ctx, field, dst, dbValue)` and `Value(ctx, field, dst, fieldValue)`, then register:

```go
schema.RegisterSerializer("encrypted", EncryptedSerializer{})
```

Use as: `gorm:"serializer:encrypted"`.

## DBResolver

Read/write splitting and multi-database support:

```go
import "gorm.io/plugin/dbresolver"

db.Use(dbresolver.Register(dbresolver.Config{
    Sources:  []gorm.Dialector{mysql.Open("source_dsn")},
    Replicas: []gorm.Dialector{mysql.Open("replica1"), mysql.Open("replica2")},
    Policy:   dbresolver.RandomPolicy{},
}))
```

- SELECT routes to replicas; INSERT/UPDATE/DELETE to sources
- Transactions stay on the initial connection
- Manual override: `db.Clauses(dbresolver.Write).First(&user)` forces source
- Table-specific configs supported
- Custom load balancing via `Policy` interface

## Composite Primary Keys

```go
type Product struct {
    ID           string `gorm:"primaryKey"`
    LanguageCode string `gorm:"primaryKey"`
    Code         string
    Name         string
}
```

For integer composite keys, disable auto-increment:

```go
ID           int64  `gorm:"primaryKey;autoIncrement:false"`
LanguageCode string `gorm:"primaryKey"`
```

`PrimaryKey` priority ordering is also available:

```go
CategoryID string `gorm:"primaryKey;priority:2"`
TypeID     string `gorm:"primaryKey;priority:1"` // TypeID first
```

## Generics API

Available since GORM v1.30.0. Provides type-safe operations with explicit `context.Context`:

```go
ctx := context.Background()

// Create
err := gorm.G[User](db).Create(ctx, &user)

// Query
user, err := gorm.G[User](db).Where("id = ?", 1).First(ctx)
users, err := gorm.G[User](db).Where("age > ?", 18).Find(ctx)

// Update
err = gorm.G[User](db).Where("id = ?", 1).Update(ctx, "Price", 200)
err = gorm.G[User](db).Where("id = ?", 1).Updates(ctx, map[string]interface{}{"price": 200})

// Delete
err = gorm.G[User](db).Where("id = ?", 1).Delete(ctx)
```

The generics API enforces context as a required parameter instead of optional, making it harder to forget context propagation.
