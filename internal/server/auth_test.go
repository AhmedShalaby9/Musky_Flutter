package server

import (
	"encoding/json"
	"golang.org/x/crypto/bcrypt"
	"musky/backend/internal/model"
	"strings"
	"testing"
)

func TestPasswordRules(t *testing.T) {
	for _, password := range []string{"", "short", strings.Repeat("a", 73)} {
		if _, err := HashPassword(password); err == nil {
			t.Fatal("accepted invalid password length")
		}
	}
	hash, err := HashPassword("a-valid-password-123")
	if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte("a-valid-password-123")) != nil {
		t.Fatal("password hashing failed")
	}
	data, _ := json.Marshal(model.User{PasswordHash: hash})
	if strings.Contains(string(data), hash) || strings.Contains(string(data), "password") {
		t.Fatal("password hash leaked in JSON")
	}
}
func TestLoginLimiter(t *testing.T) {
	l := newLoginLimiter()
	for i := 0; i < 20; i++ {
		if !l.allow("127.0.0.1") {
			t.Fatal("limited too early")
		}
	}
	if l.allow("127.0.0.1") {
		t.Fatal("missing rate limit")
	}
	if !l.allow("127.0.0.2") {
		t.Fatal("independent IP blocked")
	}
}
