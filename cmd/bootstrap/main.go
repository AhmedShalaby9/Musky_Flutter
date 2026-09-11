package main

import (
	"context"
	"log"
	"musky/backend/internal/database"
	"musky/backend/internal/server"
	"os"
	"time"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := database.Open(ctx, os.Getenv("MYSQL_DSN"))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err = database.Migrate(ctx, db); err != nil {
		log.Fatal(err)
	}
	if err = server.Bootstrap(ctx, db, os.Getenv("BOOTSTRAP_NAME"), os.Getenv("BOOTSTRAP_EMAIL"), os.Getenv("BOOTSTRAP_PASSWORD")); err != nil {
		log.Fatal("bootstrap failed (check inputs or whether the single super_admin already exists)")
	}
	log.Print("super_admin created; clear BOOTSTRAP_PASSWORD from your environment")
}
