FROM golang:latest AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
      go mod download && go mod verify

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -a -o main .

FROM scratch AS runner

COPY --from=builder /app/main /main

USER 65532:65532

EXPOSE 8080

CMD ["/main"]