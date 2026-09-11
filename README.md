# Musky Backend

MySQL-backed Go Gin API for the Musky desktop application. This first increment implements tenants, login users, and non-login clients. Products, invoices, payments, balances, and Flutter integration are the next increment; their proposed design is in [docs/design.md](docs/design.md).

## Requirements

- Go 1.25 or newer.
- MySQL 8.0.16 or newer (CHECK constraints must be enforced).
- An existing database using `utf8mb4`, and a dedicated MySQL account authorized for it.

For example, an operator can create the database using:

```sql
CREATE DATABASE musky CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

Configure the database account/password separately; never run the deployed API as MySQL root. On startup, versioned, embedded migrations create the tables. The account running migrations needs CREATE, ALTER, INDEX and REFERENCES permissions as well as normal data access. Migrations are forward-only and serialized with a MySQL named lock. MySQL DDL commits implicitly; the initial migration statements can be retried after interruption.

## First run on Windows

From `D:\Musky\backend`, use `go` if it is on PATH; otherwise use the workspace SDK:

```powershell
$env:MYSQL_DSN = 'musky:YOUR_DATABASE_PASSWORD@tcp(127.0.0.1:3306)/musky'
$env:BOOTSTRAP_NAME = 'System Owner'
$env:BOOTSTRAP_EMAIL = 'owner@example.com'
$env:BOOTSTRAP_PASSWORD = 'YOUR_UNIQUE_12_TO_72_BYTE_PASSWORD'
..\.tools\go\bin\go.exe run ./cmd/bootstrap
Remove-Item Env:BOOTSTRAP_PASSWORD
..\.tools\go\bin\go.exe run ./cmd/server
```

Bootstrap creates the single `super_admin`. A second attempt fails without modifying the existing account. There is no public registration or default password. `.env.example` documents configuration; environment variables must be set explicitly (`.env` is not automatically loaded).

The server defaults to `127.0.0.1:8080`; override `MUSKY_ADDR` if needed. Use HTTPS at your deployment reverse proxy for desktop connections over a network, and configure MySQL TLS in the DSN for remote database connections. All desktop installations sharing a business connect to the same central API. Offline synchronization is not implemented.

## APIs and permissions

See [docs/api.md](docs/api.md) for request examples and all endpoints.

- `super_admin`: the sole platform account; creates businesses and their admins and can manage tenant data explicitly by tenant ID.
- `admin`: manages traders and clients within its own tenant. Admin-account creation and changes belong to the super admin.
- `trader`: reads and edits tenant clients; cannot manage users, change client ownership, or archive clients.
- Clients have no password, role, or login endpoint. `clients.user_id` links to an active user in the same tenant on creation/reassignment. Client visibility is shared within the business.
- Email is globally unique for unambiguous login. A user belongs to one business in this first version.

Bearer sessions last 24 hours. Only SHA-256 token hashes are stored. Passwords use bcrypt and are never returned. Logout, password changes, role/email changes and account deactivation revoke sessions; disabled tenants also block authentication. Login is limited to 20 attempts per IP per 15 minutes per API process. Trusted proxies are disabled by default; configure deliberate proxy trust and a shared limiter when deploying multiple API instances. Expired session rows for a user are cleaned on login; deployments can additionally schedule deletion by `expires_at`.

## Validation

```powershell
..\.tools\go\bin\go.exe test ./...
..\.tools\go\bin\go.exe vet ./...
..\.tools\go\bin\go.exe build -o bin/musky-api.exe ./cmd/server
```

The MySQL integration test is skipped unless `MYSQL_TEST_DSN` is set. To exercise real constraints, transactions and HTTP tenant isolation, create a **fresh dedicated test database**, then run:

```powershell
$env:MYSQL_TEST_DSN = 'musky_test:YOUR_TEST_PASSWORD@tcp(127.0.0.1:3306)/musky_test'
..\.tools\go\bin\go.exe test ./... -count=1
```

The integration suite refuses a database containing users and leaves test data for inspection. Use a new test database for each run. It tests duplicate super admins, cross-tenant reads/writes/foreign keys, role escalation, last-admin protection, atomic tenant creation, passwords, logout, account deactivation and expiry.

Implementation references: [MySQL Go driver](https://github.com/go-sql-driver/mysql), [MySQL table constraints](https://dev.mysql.com/doc/refman/8.0/en/create-table.html), [bcrypt](https://pkg.go.dev/golang.org/x/crypto/bcrypt).
