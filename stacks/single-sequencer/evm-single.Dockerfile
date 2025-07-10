FROM golang:1.24-alpine AS builder

WORKDIR /src

# Install required packages for building
RUN apk add --no-cache git ca-certificates

# Download source files from GitHub
RUN git clone https://github.com/rollkit/rollkit.git

WORKDIR /src/rollkit/apps/evm/single

# Download go modules
RUN go mod download

# Build the binary for current platform
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o evm-single .

# Final stage
FROM alpine:3.22.0@sha256:8a1f59ffb675680d47db6337b49d22281a139e9d709335b492be023728e11715

WORKDIR /root

# Install ca-certificates for HTTPS requests
RUN apk add --no-cache ca-certificates curl wget

# Copy the binary from builder stage
COPY --from=builder /src/rollkit/apps/evm/single/evm-single /usr/bin/evm-single
