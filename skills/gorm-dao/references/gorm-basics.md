# GORM Basics

## Table of Contents

1. [Models and Struct Tags](#models-and-struct-tags)
2. [Conventions](#conventions)
3. [Connecting to Databases](#connecting-to-databases)
4. [Create](#create)
5. [Query](#query)
6. [Update](#update)
7. [Delete](#delete)
8. [Error Handling](#error-handling)
9. [Context](#context)
10. [Logger](#logger)
11. [Sessions](#sessions)
12. [Raw SQL](#raw-sql)

## Models and Struct Tags

### gorm.Model

The built-in `gorm.Model` provides four standard fields:

```go
type Model struct {
    ID        uint           `gorm:"primaryKey"`
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`
}
```

Embed it in your own structs to get automatic ID, timestamps, and soft delete.

### Field-level permissions

```go
Name string `gorm:"<-:create"`          // read + create only
Name string `gorm:"<-:update"`          // read + update only
Name string `gorm:"<-"`                 // read + create + update
Name string `gorm:"->"`                 // read-only
Name string `gorm:"->:false;<-:create"` // create-only
Name string `gorm:"-"`                  // ignored by GORM entirely
Name string `gorm:"-:all"`              // ignored for all operations
Name string `gorm:"-:migration"`        // ignored in migration only
```

### Time tracking

```go
Created int64 `gorm:"autoCreateTime"`       // unix seconds on create
Updated int64 `gorm:"autoUpdateTime:nano"`  // unix nanoseconds on update
Updated int64 `gorm:"autoUpdateTime:milli"` // unix milliseconds on update
```

Disable: `gorm:"autoCreateTime:false"` or `gorm:"autoUpdateTime:false"`.

### Embedded structs

Anonymous fields are included automatically. Named fields need the tag:

```go
type Blog struct {
    ID      int
    Author  Author `gorm:"embedded;embeddedPrefix:author_"`
    // produces columns: author_name, author_email, etc.
}
```

### All struct tags

| Tag                      | Description                                             |
| ------------------------ | ------------------------------------------------------- |
| `column`                 | Column name                                             |
| `type`                   | Column data type (e.g., `varchar(100)`, `text`)         |
| `size`                   | Column size (e.g., `size:256`)                          |
| `primaryKey`             | Primary key                                             |
| `unique`                 | Unique constraint                                       |
| `default`                | Default value                                           |
| `precision`              | Numeric precision                                       |
| `scale`                  | Numeric scale                                           |
| `not null`               | NOT NULL                                                |
| `autoIncrement`          | Auto-increment                                          |
| `autoIncrementIncrement` | Auto-increment step                                     |
| `embedded`               | Embed the struct                                        |
| `embeddedPrefix`         | Prefix for embedded struct columns                      |
| `autoCreateTime`         | Track creation time                                     |
| `autoUpdateTime`         | Track update time                                       |
| `index`                  | Create index (see migration docs)                       |
| `uniqueIndex`            | Create unique index                                     |
| `check`                  | CHECK constraint (e.g., `check:age > 13`)               |
| `<-`                     | Write permission (`<-:create`, `<-:update`, `<-:false`) |
| `->`                     | Read permission (`->:false` for write-only)             |
| `-`                      | Ignore field (`-:all`, `-:migration`)                   |
| `comment`                | Column comment in migration                             |
| `serializer`             | Serializer name (json, gob, unixtime, or custom)        |

## Conventions

### Naming

- **Primary key**: Field named `ID` is the primary key by default.
- **Table names**: Struct name -> snake_case -> pluralized. `User` -> `users`, `UserProfile` -> `user_profiles`.
- **Column names**: Field name -> snake_case. `MemberNumber` -> `member_number`.

### Override table name

Implement the `Tabler` interface:

```go
func (User) TableName() string { return "profiles" }
```

Results are cached -- for dynamic table names, use Scopes instead.

### NamingStrategy

Customize globally via `gorm.Config`:

```go
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
    NamingStrategy: schema.NamingStrategy{
        TablePrefix:   "t_",
        SingularTable: true,  // User -> t_user (not t_users)
        NoLowerCase:   true,
    },
})
```

### Timestamps

- `CreatedAt`: Set on insert if zero. Bypass with `UpdateColumn`.
- `UpdatedAt`: Set on every save/update. Bypass with `UpdateColumn`.

## Connecting to Databases

### PostgreSQL

```go
import "gorm.io/driver/postgres"

dsn := "host=localhost user=gorm password=gorm dbname=gorm port=9920 sslmode=disable TimeZone=Asia/Shanghai"
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
```

Uses pgx driver. For connection pool managers, disable prepared statement cache:
`postgres.New(postgres.Config{PreferSimpleProtocol: true})`

### MySQL

```go
import "gorm.io/driver/mysql"

dsn := "user:pass@tcp(127.0.0.1:3306)/dbname?charset=utf8mb4&parseTime=True&loc=Local"
db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
```

Always use `charset=utf8mb4` and `parseTime=True`.

### SQLite

```go
import "gorm.io/driver/sqlite"

db, err := gorm.Open(sqlite.Open("gorm.db"), &gorm.Config{})
// In-memory: sqlite.Open("file::memory:?cache=shared")
```

### SQL Server

```go
import "gorm.io/driver/sqlserver"

dsn := "sqlserver://gorm:LoremIpsum86@localhost:9930?database=gorm"
db, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
```

### Connection pool

```go
sqlDB, err := db.DB()
sqlDB.SetMaxIdleConns(10)
sqlDB.SetMaxOpenConns(100)
sqlDB.SetConnMaxLifetime(time.Hour)
```

### Existing connection

All drivers support initializing from an existing `*sql.DB`:

```go
db, err := gorm.Open(postgres.New(postgres.Config{Conn: existingSQLDB}), &gorm.Config{})
```

## Create

### Single record

```go
user := User{Name: "Jinzhu", Age: 18}
result := db.Create(&user)
// user.ID is populated after insert
// result.Error contains any error
// result.RowsAffected is the count
```

### Batch insert

```go
users := []User{{Name: "a"}, {Name: "b"}, {Name: "c"}}
db.Create(&users)
db.CreateInBatches(users, 100) // insert in batches of 100
```

### Select/omit fields

```go
db.Select("Name", "Age").Create(&user)   // INSERT only Name and Age
db.Omit("Name").Create(&user)            // INSERT everything except Name
```

### Upsert (on conflict)

```go
// Do nothing on conflict
db.Clauses(clause.OnConflict{DoNothing: true}).Create(&user)

// Update specific columns on conflict
db.Clauses(clause.OnConflict{
    Columns:   []clause.Column{{Name: "id"}},
    DoUpdates: clause.AssignmentColumns([]string{"name", "age"}),
}).Create(&users)

// Update all columns on conflict
db.Clauses(clause.OnConflict{UpdateAll: true}).Create(&users)
```

### Create from map

```go
db.Model(&User{}).Create(map[string]interface{}{
    "Name": "jinzhu", "Age": 18,
})
```

## Query

### Single record

```go
db.First(&user)                       // ORDER BY id LIMIT 1
db.Take(&user)                        // LIMIT 1 (no order guarantee)
db.Last(&user)                        // ORDER BY id DESC LIMIT 1
db.First(&user, 10)                   // WHERE id = 10
db.First(&user, "id = ?", "1b74413f") // string PK
db.Find(&users, []int{1, 2, 3})      // WHERE id IN (1, 2, 3)
```

`First` and `Last` require a primary key or explicit `Order()`. They return `ErrRecordNotFound` when no match; `Find` does not.

### Conditions

```go
// String conditions (parameterized -- never interpolate user input)
db.Where("name = ?", "jinzhu").First(&user)
db.Where("name <> ?", "jinzhu").Find(&users)
db.Where("name IN ?", []string{"a", "b"}).Find(&users)
db.Where("name LIKE ?", "%jin%").Find(&users)
db.Where("name = ? AND age >= ?", "jinzhu", "22").Find(&users)
db.Where("updated_at > ?", lastWeek).Find(&users)
db.Where("created_at BETWEEN ? AND ?", lastWeek, today).Find(&users)

// Struct conditions (zero-value fields are EXCLUDED)
db.Where(&User{Name: "jinzhu", Age: 20}).First(&user)
// To include zero values, specify fields explicitly:
db.Where(&User{Name: "jinzhu"}, "name", "Age").Find(&users)

// Map conditions (includes zero values)
db.Where(map[string]interface{}{"name": "jinzhu", "age": 0}).Find(&users)

// Not
db.Not("name = ?", "jinzhu").First(&user)
db.Not(map[string]interface{}{"name": []string{"a", "b"}}).Find(&users)

// Or
db.Where("role = ?", "admin").Or("role = ?", "super_admin").Find(&users)
```

**Important**: Struct-based conditions skip zero-value fields (`0`, `""`, `false`). Use maps, pointer fields, or `sql.Null*` types to query for zero values.

### Select, Order, Limit, Offset

```go
db.Select("name", "age").Find(&users)
db.Select("COALESCE(age, ?)", 42).Find(&users)
db.Order("age desc, name").Find(&users)
db.Limit(10).Offset(5).Find(&users)
db.Limit(-1)  // cancel limit from a chain
db.Distinct("name", "age").Find(&results)
```

### Group and Having

```go
db.Model(&User{}).Select("name, sum(age) as total").
    Group("name").Having("name = ?", "group").Find(&results)
```

### Joins

```go
db.Model(&User{}).Select("users.name, emails.email").
    Joins("left join emails on emails.user_id = users.id").
    Scan(&result)

// With conditions on the join
db.Joins("JOIN emails ON emails.user_id = users.id AND emails.email = ?", "jinzhu@example.org").
    Find(&user)

// Named Joins (loads association fields via LEFT JOIN)
db.Joins("Company").Find(&users)       // LEFT JOIN
db.InnerJoins("Company").Find(&users)  // INNER JOIN
db.Joins("Company", db.Where(&Company{Alive: true})).Find(&users)
```

### Pluck (single column)

```go
var ages []int64
db.Model(&User{}).Pluck("age", &ages)

var names []string
db.Model(&User{}).Distinct().Pluck("name", &names)
```

### Count

```go
var count int64
db.Model(&User{}).Where("name = ?", "jinzhu").Count(&count)
```

### Iteration

Row by row:

```go
rows, err := db.Model(&User{}).Where("name = ?", "jinzhu").Rows()
defer rows.Close()
for rows.Next() {
    var user User
    db.ScanRows(rows, &user)
}
```

In batches:

```go
db.Where("processed = ?", false).FindInBatches(&results, 100, func(tx *gorm.DB, batch int) error {
    for _, result := range results {
        // process each record
    }
    return nil
})
```

### FirstOrInit / FirstOrCreate

```go
// Initialize (does not save to DB)
db.FirstOrInit(&user, User{Name: "non_existing"})
db.Where(User{Name: "jinzhu"}).Attrs(User{Age: 20}).FirstOrInit(&user) // Attrs only applied if not found

// Create (saves to DB if not found)
db.FirstOrCreate(&user, User{Name: "non_existing"})
db.Where(User{Name: "jinzhu"}).Assign(User{Age: 20}).FirstOrCreate(&user) // Assign always applied
```

### Find to map

```go
var result map[string]interface{}
db.Model(&User{}).First(&result, "id = ?", 1)

var results []map[string]interface{}
db.Model(&User{}).Find(&results)
```

### Locking

```go
db.Clauses(clause.Locking{Strength: "UPDATE"}).Find(&users)       // FOR UPDATE
db.Clauses(clause.Locking{Strength: "SHARE"}).Find(&users)        // FOR SHARE
db.Clauses(clause.Locking{Strength: "UPDATE", Options: "NOWAIT"}).Find(&users)
db.Clauses(clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}).Find(&users)
```

Note: SQLite does not support row-level locking. gormlite silently drops these clauses.

### Sub-queries

```go
db.Where("amount > (?)", db.Table("orders").Select("AVG(amount)")).Find(&orders)

// FROM subquery
subQuery := db.Model(&User{}).Select("name", "age")
db.Table("(?) as u", subQuery).Where("age = ?", 18).Find(&User{})
```

### Group conditions

```go
db.Where(
    db.Where("pizza = ?", "pepperoni").Where(
        db.Where("size = ?", "small").Or("size = ?", "medium"),
    ),
).Or(
    db.Where("pizza = ?", "hawaiian").Where("size = ?", "xlarge"),
).Find(&Pizza{})
```

## Update

### Single column

```go
db.Model(&user).Update("name", "hello")
// UPDATE users SET name='hello', updated_at=... WHERE id=111
```

### Multiple columns

```go
// Struct (skips zero-value fields)
db.Model(&user).Updates(User{Name: "hello", Age: 18, Active: false})
// UPDATE users SET name='hello', age=18 WHERE id=111 (Active skipped!)

// Map (includes zero values)
db.Model(&user).Updates(map[string]interface{}{"name": "hello", "age": 18, "active": false})
```

### Select/Omit with update

```go
db.Model(&user).Select("Name").Updates(map[string]interface{}{"name": "hello", "age": 18})
// UPDATE users SET name='hello' WHERE id=111

db.Model(&user).Omit("Name").Updates(...)
// UPDATE everything except Name

db.Model(&user).Select("*").Updates(User{Name: "hello", Active: false})
// Includes zero-value fields when using Select("*") with struct
```

### SQL expressions

```go
db.Model(&product).Update("price", gorm.Expr("price * ? + ?", 2, 100))
// UPDATE products SET price = price * 2 + 100
```

### Batch updates

```go
db.Model(&User{}).Where("role = ?", "admin").Update("active", false)
// UPDATE users SET active=false WHERE role='admin'
```

### Without hooks or time tracking

```go
db.Model(&user).UpdateColumn("name", "hello")   // single column
db.Model(&user).UpdateColumns(User{Name: "hello"}) // multiple
```

### Save (upsert all fields)

```go
db.Save(&user) // creates if no PK, updates all fields if PK exists
```

## Delete

### Basic

```go
db.Delete(&user)                    // needs primary key set
db.Delete(&User{}, 10)             // by PK value
db.Delete(&User{}, []int{1, 2, 3}) // batch by PK
db.Where("email LIKE ?", "%jin%").Delete(&Email{})
```

### Soft delete

Models with `gorm.DeletedAt` automatically soft delete. `DELETE` sets the `deleted_at` timestamp; all queries auto-add `WHERE deleted_at IS NULL`.

```go
db.Unscoped().Find(&users)            // include soft-deleted records
db.Unscoped().Delete(&user)           // permanently delete
```

## Error Handling

```go
if err := db.Where("name = ?", "jinzhu").First(&user).Error; err != nil {
    if errors.Is(err, gorm.ErrRecordNotFound) {
        // handle not found
    }
    // handle other errors
}
```

### Dialect-translated errors

Enable with `TranslateError: true` in config:

```go
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{TranslateError: true})
```

Then check:

- `gorm.ErrDuplicatedKey` -- unique constraint violation
- `gorm.ErrForeignKeyViolated` -- FK violation

## Context

```go
db.WithContext(ctx).Find(&users)

// Timeout
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()
db.WithContext(ctx).Find(&users)
```

Context is available in hooks via `tx.Statement.Context`.

## Logger

```go
newLogger := logger.New(
    log.New(os.Stdout, "\r\n", log.LstdFlags),
    logger.Config{
        SlowThreshold:             time.Second,
        LogLevel:                  logger.Silent,  // Silent, Error, Warn, Info
        IgnoreRecordNotFoundError: true,
        ParameterizedQueries:      true,
        Colorful:                  false,
    },
)
db, err := gorm.Open(sqlite.Open("test.db"), &gorm.Config{Logger: newLogger})

db.Debug().Where("name = ?", "jinzhu").First(&User{}) // one-off debug logging
```

## Sessions

Sessions create a new `*gorm.DB` with specific configuration:

```go
tx := db.Session(&gorm.Session{
    DryRun:                   true,   // generate SQL without executing
    PrepareStmt:              true,   // cache prepared statements
    NewDB:                    true,   // fresh DB without inherited conditions
    SkipHooks:                true,   // bypass hook methods
    SkipDefaultTransaction:   true,   // no auto-transaction
    AllowGlobalUpdate:        true,   // allow unconditional update/delete
    FullSaveAssociations:     true,   // full update of associated data
    QueryFields:              true,   // select by field names
    CreateBatchSize:          1000,   // default batch size for Create
    Context:                  ctx,    // set context
})
```

## Raw SQL

```go
db.Raw("SELECT id, name FROM users WHERE id = ?", 3).Scan(&result)
db.Exec("UPDATE orders SET shipped_at = ? WHERE id IN ?", time.Now(), []int64{1, 2, 3})
```

Use `db.ToSQL()` to get the generated SQL without executing:

```go
sql := db.ToSQL(func(tx *gorm.DB) *gorm.DB {
    return tx.Model(&User{}).Where("id = ?", 100).Limit(10).Order("age desc").Find(&[]User{})
})
```
