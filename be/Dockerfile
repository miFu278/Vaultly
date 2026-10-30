# syntax=docker/dockerfile:1

# Build stage. GOTOOLCHAIN=auto lets the image fetch a newer patch release if
# go.mod asks for one the base image does not ship yet.
ARG GO_VERSION=1.27
FROM golang:${GO_VERSION}-alpine AS build
ENV GOTOOLCHAIN=auto CGO_ENABLED=0
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

# Runtime stage. The server needs a shell only for the healthcheck, so busybox
# plus CA certificates for the R2 calls is the whole dependency list.
FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -H -u 10001 vaultly

WORKDIR /app
COPY --from=build /out/server ./server
# main.go runs this schema on boot; it must sit next to the working directory.
COPY migrations ./migrations

USER 10001
EXPOSE 8080

# Uploads spool to $TMPDIR (the container's own disk), so the host needs free
# space of roughly twice MAX_UPLOAD_MB.
ENV TMPDIR=/tmp

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO- "http://127.0.0.1:${PORT:-8080}/health" || exit 1

ENTRYPOINT ["./server"]
