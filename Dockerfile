# ==============================================================================
# ETAPA 1: Compilación (Build Stage)
# ==============================================================================
FROM golang:1.24-alpine3.20 AS builder

# Instalar certificados CA por si la app realiza llamadas HTTPS externas durante el build
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copiar dependencias primero para aprovechar el caché de capas de Docker
COPY go.mod go.sum* ./
RUN go mod download || true

# Copiar el código fuente
COPY . .

# Compilar un binario completamente estático sin dependencias de C (CGO_ENABLED=0)
# -ldflags="-s -w" elimina símbolos de depuración y tablas de símbolos para reducir el tamaño
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w" \
    -o /app/server ./src

# Crear un usuario no privilegiado en la etapa de build
RUN echo "nonroot:x:65532:65532:nonroot:/:" > /etc/passwd-nonroot

# ==============================================================================
# ETAPA 2: Runtime Mínimo y Seguro (Distroless Stage)
# ==============================================================================
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /

# Copiar las zonas horarias y certificados CA desde la etapa de compilación
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /etc/passwd-nonroot /etc/passwd

# Copiar el binario compilado desde el builder
COPY --from=builder /app/server /server

# Ejecutar con el usuario no privilegiado (UID 65532)
USER nonroot:nonroot

# Exponer el puerto de la aplicación (e.g., 8080)
EXPOSE 8080

# Comando de entrada
ENTRYPOINT ["/server"]