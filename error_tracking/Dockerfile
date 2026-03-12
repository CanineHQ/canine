FROM rust:1.85-alpine AS builder
RUN apk add --no-cache musl-dev
WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY src/ src/
RUN cargo build --release

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/target/release/error-tracking /usr/local/bin/error-tracking
RUN mkdir -p /data
ENV DATABASE_PATH=/data/errors.db
EXPOSE 3001
CMD ["error-tracking"]
