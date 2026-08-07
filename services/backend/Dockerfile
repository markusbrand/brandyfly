# syntax=docker/dockerfile:1.8
FROM golang:1.25-alpine AS build

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
COPY internal ./internal

RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} \
    go build -trimpath -ldflags="-s -w" -o /out/brandyfly-backend ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/brandyfly-backend /brandyfly-backend

USER nonroot:nonroot
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/brandyfly-backend", "-healthcheck"]
ENTRYPOINT ["/brandyfly-backend"]
