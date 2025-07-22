# Stage 1 - Builder
FROM golang:latest AS builder

WORKDIR /app

# Copy dependency files first to apply caching
COPY go.mod go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download && go mod verify

# Copy the rest of the app
COPY . .

# Access secret paased during build with --secret flag
RUN --mount=type=secret,id=secret,target=/run/secrets/.env.build \
    echo "Using build secret at /run/secrets/.env.build"

# Build the Go binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -o main .

# Stage 2 - Minimal runtime image
FROM alpine:latest

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main .

EXPOSE 8080

# Entry point to run the binary
CMD ["./main"]
