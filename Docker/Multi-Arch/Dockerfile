# Pick a multi architecture base image
FROM golang:latest as builder

RUN echo "Architecture: $(uname -m)" > /architecture.txt

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Final image
FROM alpine:latest

# Copy binary
COPY --from=builder /app/main .

# Copy architecture info
COPY --from=builder /architecture.txt .

EXPOSE 8080

# Print architecture at runtime, then start the app
CMD sh -c "cat /architecture.txt && ./main"
