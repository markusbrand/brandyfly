package server

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"time"
)

const shutdownTimeout = 10 * time.Second

func NewHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(response http.ResponseWriter, request *http.Request) {
		expectedToken := os.Getenv("BRANDYFLY_HEALTH_TOKEN")
		if expectedToken == "" {
			http.Error(response, "Unauthorized", http.StatusUnauthorized)
			return
		}

		expectedAuth := "Bearer " + expectedToken
		actualAuth := request.Header.Get("Authorization")

		// Hash tokens before comparison to prevent length leakage during ConstantTimeCompare
		expectedHash := sha256.Sum256([]byte(expectedAuth))
		actualHash := sha256.Sum256([]byte(actualAuth))

		if subtle.ConstantTimeCompare(actualHash[:], expectedHash[:]) != 1 {
			http.Error(response, "Unauthorized", http.StatusUnauthorized)
			return
		}
		response.Header().Set("X-Content-Type-Options", "nosniff")
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(response, "{\"status\":\"ok\"}\n")
	})
	return mux
}

func Run(ctx context.Context, logger *slog.Logger, address string) error {
	httpServer := &http.Server{
		Addr:              address,
		Handler:           NewHandler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		logger.Info("backend listening", "address", address)
		errCh <- httpServer.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("listen: %w", err)
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}

	err := <-errCh
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("shutdown listener: %w", err)
	}
	return nil
}

func CheckHealth(url string, timeout time.Duration) error {
	client := &http.Client{Timeout: timeout}
	request, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("create health request: %w", err)
	}

	if token := os.Getenv("BRANDYFLY_HEALTH_TOKEN"); token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}

	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("request health endpoint: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected health status: %s", response.Status)
	}
	return nil
}
