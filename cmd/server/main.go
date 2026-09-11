package main

import (
	"log"
	"musky/backend/internal/server"
	"os"
)

func main() {
	addr := os.Getenv("MUSKY_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	log.Printf("Musky API listening on %s", addr)
	if err := server.New().Run(addr); err != nil {
		log.Fatal(err)
	}
}
