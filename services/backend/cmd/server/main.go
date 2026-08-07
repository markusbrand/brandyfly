package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/markusbrand/brandyfly/services/backend/internal/server"
)

const defaultAddress = ":8080"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	if len(os.Args) == 2 && os.Args[1] == "-healthcheck" {
		if err := server.CheckHealth("http://127.0.0.1:8080/healthz", 2*time.Second); err != nil {
			logger.Error("health check failed", "error", err)
			os.Exit(1)
		}
		return
	}

	address := os.Getenv("BRANDYFLY_LISTEN_ADDRESS")
	if address == "" {
		address = defaultAddress
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := server.Run(ctx, logger, address); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
