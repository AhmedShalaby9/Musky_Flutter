package main

import (
	"context"
	"errors"
	"log"
	"musky/backend/internal/database"
	"musky/backend/internal/server"
	"net/http"
	"os"
	"os/signal"
	"time"
)

func main() {
	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		log.Fatal("MYSQL_DSN is required; see .env.example")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	db, err := database.Open(ctx, dsn)
	if err != nil {
		cancel()
		log.Fatal(err)
	}
	defer db.Close()
	if err = database.Migrate(ctx, db); err != nil {
		cancel()
		log.Fatal(err)
	}
	cancel()
	addr := os.Getenv("MUSKY_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	srv := &http.Server{Addr: addr, Handler: server.New(db), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second}
	stop, cancelSignal := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancelSignal()
	go func() {
		<-stop.Done()
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}()
	log.Printf("Musky API listening on %s", addr)
	if err = srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
