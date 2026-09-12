package database

import (
	"context"
	"os"
	"strings"
	"testing"
)

func TestTraderMigrationPreservesExistingData(t *testing.T) {
	dsn := os.Getenv("MYSQL_MIGRATION_TEST_DSN")
	if dsn == "" {
		t.Skip("set MYSQL_MIGRATION_TEST_DSN to a fresh dedicated database")
	}
	ctx := context.Background()
	db, err := Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	var tables int
	if err = db.QueryRow("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()").Scan(&tables); err != nil || tables != 0 {
		t.Fatal("migration test requires an empty database", err)
	}
	body, err := migrations.ReadFile("migrations/001_identity.sql")
	if err != nil {
		t.Fatal(err)
	}
	for _, statement := range strings.Split(string(body), ";") {
		if strings.TrimSpace(statement) == "" {
			continue
		}
		if _, err = db.Exec(statement); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = db.Exec("INSERT INTO tenants(id,name) VALUES (1,'Legacy tenant')"); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("INSERT INTO users(id,tenant_id,name,email,password_hash,role) VALUES (1,1,'Legacy admin','legacy@example.com','hash','admin')"); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("INSERT INTO clients(tenant_id,user_id,name) VALUES (1,1,'Existing client')"); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err == nil || !strings.Contains(err.Error(), "exactly one trader") {
		t.Fatal("missing owner must stop migration", err)
	}
	if _, err = db.Exec("INSERT INTO users(tenant_id,name,email,password_hash,role) VALUES (1,'Owner','owner@example.com','hash','trader'),(1,'Second','second@example.com','hash','trader')"); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err == nil || !strings.Contains(err.Error(), "exactly one trader") {
		t.Fatal("shared traders must stop migration", err)
	}
	// Simulate an operator explicitly resolving the old role assignment.
	if _, err = db.Exec("UPDATE users SET role='admin' WHERE email='second@example.com'"); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err != nil {
		t.Fatal("repeat migration", err)
	}
	var name string
	var owner uint64
	if err = db.QueryRow("SELECT name,user_id FROM clients WHERE tenant_id=1").Scan(&name, &owner); err != nil || name != "Existing client" || owner != 1 {
		t.Fatal("client data changed", err, name, owner)
	}
	// Emulate a crash after the atomic ALTER but before the version was recorded.
	if _, err = db.Exec("DELETE FROM schema_migrations WHERE version='002_one_trader_per_tenant.sql'"); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err != nil {
		t.Fatal("interrupted migration did not resume", err)
	}
}
