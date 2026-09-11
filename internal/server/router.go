package server

import (
	"github.com/gin-gonic/gin"
	"net/http"
)

func New() *gin.Engine {
	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "musky-api"})
	})
	return router
}
