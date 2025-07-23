FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy Go module files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# CGO_ENABLED=0 ensures a static binary without external C dependencies.
RUN CGO_ENABLED=0 go build -o app -ldflags="-s -w" .

# ----------- RUNNER STAGE --------#
FROM gcr.io/distroless/static-debian12:nonroot

# Copy the compiled binary from the builder stage
COPY --from=builder /app/app /app/app

USER nonroot

ENTRYPOINT ["/app/app"]