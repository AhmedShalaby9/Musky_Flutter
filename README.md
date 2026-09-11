# Musky Backend

Go Gin API for the Musky desktop application. Business functionality will be added after requirements are defined.

Requires Go 1.25 or newer.

```sh
go mod download
go run ./cmd/server
```

The server listens at `127.0.0.1:8080` by default. Set `MUSKY_ADDR` to override it.

`GET /health` returns `{"service":"musky-api","status":"ok"}`.

```sh
go test ./...
go build -o bin/musky-api ./cmd/server
```
