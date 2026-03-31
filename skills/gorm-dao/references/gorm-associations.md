# GORM Associations

## Table of Contents

1. [Belongs To](#belongs-to)
2. [Has One](#has-one)
3. [Has Many](#has-many)
4. [Many to Many](#many-to-many)
5. [Polymorphic Associations](#polymorphic-associations)
6. [Preloading (Eager Loading)](#preloading)
7. [Association Mode](#association-mode)
8. [Auto-Save and Cascade](#auto-save-and-cascade)

## Belongs To

The current model holds the foreign key. Used when a record "belongs to" another.

```go
type User struct {
    gorm.Model
    Name      string
    CompanyID int       // foreign key column
    Company   Company   // association field
}

type Company struct {
    ID   int
    Name string
}
```

### Override foreign key

```go
type User struct {
    gorm.Model
    Name         string
    CompanyRefer int
    Company      Company `gorm:"foreignKey:CompanyRefer"`
}
```

### Override references

```go
type User struct {
    gorm.Model
    Name      string
    CompanyID string
    Company   Company `gorm:"references:Code"` // references Company.Code instead of Company.ID
}

type Company struct {
    ID   int
    Code string
    Name string
}
```

### Foreign key constraints

```go
type User struct {
    gorm.Model
    Name      string
    CompanyID int
    Company   Company `gorm:"constraint:OnUpdate:CASCADE,OnDelete:SET NULL;"`
}
```

Options: `CASCADE`, `SET NULL`, `RESTRICT`, `NO ACTION`, `SET DEFAULT`.

## Has One

The other model holds the foreign key. Used when a record "has one" of something.

```go
type User struct {
    gorm.Model
    CreditCard CreditCard // User has one CreditCard
}

type CreditCard struct {
    gorm.Model
    Number string
    UserID uint   // foreign key (convention: OwnerTypeName + ID)
}
```

### Override foreign key

```go
type User struct {
    gorm.Model
    CreditCard CreditCard `gorm:"foreignKey:UserName"`
}
type CreditCard struct {
    gorm.Model
    Number   string
    UserName string // foreign key
}
```

### Override references

```go
type User struct {
    gorm.Model
    Name       string     `gorm:"index"`
    CreditCard CreditCard `gorm:"foreignKey:UserName;references:Name"`
}
```

### Self-referential

```go
type User struct {
    gorm.Model
    Name      string
    ManagerID *uint   // nullable (top-level managers have no manager)
    Manager   *User
}
```

## Has Many

The other model holds the foreign key. Used when a record has a collection.

```go
type User struct {
    gorm.Model
    CreditCards []CreditCard // User has many CreditCards
}

type CreditCard struct {
    gorm.Model
    Number string
    UserID uint   // foreign key
}
```

### Override foreign key and references

```go
type User struct {
    gorm.Model
    MemberNumber string
    CreditCards  []CreditCard `gorm:"foreignKey:UserNumber;references:MemberNumber"`
}

type CreditCard struct {
    gorm.Model
    Number     string
    UserNumber string
}
```

## Many to Many

Both models reference each other through a join table.

```go
type User struct {
    gorm.Model
    Languages []Language `gorm:"many2many:user_languages;"`
}

type Language struct {
    gorm.Model
    Name  string
    Users []*User `gorm:"many2many:user_languages;"` // back-reference (optional)
}
```

GORM auto-creates the `user_languages` join table with `user_id` and `language_id` columns.

### Custom join table

```go
type PersonAddress struct {
    PersonID  int `gorm:"primaryKey"`
    AddressID int `gorm:"primaryKey"`
    CreatedAt time.Time
    DeletedAt gorm.DeletedAt
}

// Must call SetupJoinTable before AutoMigrate
db.SetupJoinTable(&Person{}, "Addresses", &PersonAddress{})
db.SetupJoinTable(&Address{}, "People", &PersonAddress{})
db.AutoMigrate(&Person{}, &Address{})
```

### Override join table keys

```go
type User struct {
    gorm.Model
    Profiles []Profile `gorm:"many2many:user_profiles;foreignKey:Refer;joinForeignKey:UserReferID;References:UserRefer;joinReferences:ProfileRefer"`
}
```

### Self-referential many-to-many

```go
type User struct {
    gorm.Model
    Friends []*User `gorm:"many2many:user_friends"`
}
```

## Polymorphic Associations

A single association field that can belong to different model types.

```go
type Dog struct {
    ID   int
    Name string
    Toys []Toy `gorm:"polymorphic:Owner;"`
}

type Cat struct {
    ID   int
    Name string
    Toys []Toy `gorm:"polymorphic:Owner;"`
}

type Toy struct {
    ID        int
    Name      string
    OwnerID   int
    OwnerType string // "dogs" or "cats"
}
```

Override polymorphic value:

```go
Toys []Toy `gorm:"polymorphic:Owner;polymorphicValue:master"`
// OwnerType will be "master" instead of table name
```

## Preloading

### Preload (separate queries)

```go
db.Preload("Orders").Find(&users)
// SELECT * FROM users;
// SELECT * FROM orders WHERE user_id IN (1,2,3,...);
```

### Multiple associations

```go
db.Preload("Orders").Preload("Profile").Preload("Role").Find(&users)
```

### Preload all (non-nested)

```go
db.Preload(clause.Associations).Find(&users)
// Preloads all top-level associations but NOT nested ones
```

### Nested preloading

```go
db.Preload("Orders.OrderItems.Product").Find(&users)

// Or preload each level separately with conditions
db.Preload("Orders", "state = ?", "paid").
    Preload("Orders.OrderItems").
    Find(&users)
```

### Conditional preloading

```go
// String condition
db.Preload("Orders", "state NOT IN (?)", "cancelled").Find(&users)

// Function condition
db.Preload("Orders", func(db *gorm.DB) *gorm.DB {
    return db.Order("orders.amount DESC")
}).Find(&users)

// Inline conditions on nested preloads
db.Preload("Orders.OrderItems", func(db *gorm.DB) *gorm.DB {
    return db.Where("quantity > ?", 0)
}).Find(&users)
```

### Joins preloading (single query)

For belongs-to and has-one relationships, use `Joins` instead of `Preload` to load in a single SQL query via LEFT JOIN:

```go
db.Joins("Company").Find(&users)
// SELECT users.*, Company.id, Company.name FROM users LEFT JOIN companies AS Company ON ...

db.InnerJoins("Company").Find(&users)
// Uses INNER JOIN instead

// With conditions
db.Joins("Company", db.Where(&Company{Alive: true})).Find(&users)

// Nested joins
db.Joins("Manager").Joins("Manager.Company").Find(&users)
```

Joins preloading works with `First`, `Find`, `Scan`, and other finishers.

### Embedded preloading

For embedded structs with associations:

```go
type Address struct {
    CountryID int
    Country   Country
}

type User struct {
    gorm.Model
    PostalAddress Address `gorm:"embedded;embeddedPrefix:postal_"`
}

db.Preload("PostalAddress.Country").Find(&users)
```

## Association Mode

Operate on associations directly without loading the full record:

```go
// Find associated records
var languages []Language
db.Model(&user).Association("Languages").Find(&languages)

// Append
db.Model(&user).Association("Languages").Append([]Language{langZH, langEN})
db.Model(&user).Association("CreditCard").Append(&CreditCard{Number: "411111111111"})

// Replace all
db.Model(&user).Association("Languages").Replace([]Language{langZH, langEN})

// Delete (removes from join table for many2many; nullifies FK for has-one/has-many)
db.Model(&user).Association("Languages").Delete(langZH, langEN)

// Clear all
db.Model(&user).Association("Languages").Clear()

// Count
count := db.Model(&user).Association("Languages").Count()
```

### Batch mode

Association mode works with slices too:

```go
db.Model(&users).Association("Role").Find(&roles)
// finds roles for all users in the slice
```

## Auto-Save and Cascade

### Auto-create on Create

GORM auto-saves associations and their references when creating a record:

```go
user := User{
    Name: "jinzhu",
    CreditCard: CreditCard{Number: "411111111111"},
}
db.Create(&user)
// Creates both user and credit_card, sets foreign key automatically
```

### Skip auto-create

```go
db.Omit(clause.Associations).Create(&user)
// Skips all association saves

db.Omit("CreditCard").Create(&user)
// Skips specific association
```

### FullSaveAssociations

By default, `Save` on the parent does not deeply update associations. Enable with:

```go
db.Session(&gorm.Session{FullSaveAssociations: true}).Updates(&user)
```

### Delete with Select (cascade)

```go
// Delete user's account when deleting user
db.Select("Account").Delete(&user)

// Delete user's orders and credit cards
db.Select("Orders", "CreditCards").Delete(&user)

// Delete all associations
db.Select(clause.Associations).Delete(&user)

// Delete with condition
db.Select("Account").Where("role = ?", "admin").Delete(&user)
```

### Association tags reference

| Tag                | Description                         |
| ------------------ | ----------------------------------- |
| `foreignKey`       | Foreign key field name              |
| `references`       | Reference field name                |
| `polymorphic`      | Polymorphic type field name         |
| `polymorphicValue` | Custom polymorphic value            |
| `many2many`        | Join table name                     |
| `joinForeignKey`   | Join table foreign key              |
| `joinReferences`   | Join table reference key            |
| `constraint`       | FK constraints (OnUpdate, OnDelete) |
