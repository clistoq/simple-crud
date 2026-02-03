# Zig Backend Dockerfile
FROM alpine:3.19 AS builder

# Install Zig
RUN apk add --no-cache curl xz
RUN curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C /opt
ENV PATH="/opt/zig-linux-x86_64-0.13.0:$PATH"

WORKDIR /app
COPY . .

# Build the application
RUN zig build -Doptimize=ReleaseSafe

# Runtime stage
FROM alpine:3.19

WORKDIR /app
COPY --from=builder /app/zig-out/bin/zig-server /app/server

EXPOSE 8080

CMD ["./server"]
