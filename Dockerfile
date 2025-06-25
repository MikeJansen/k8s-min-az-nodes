FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o app main.go

FROM scratch
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]