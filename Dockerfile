# ------------------------------------------------------------------------------
# STAGE 1: Builder
# ------------------------------------------------------------------------------
    #crear una imagen basada en Go 1.22 y a la etapa se le llamará "builder"
FROM golang:1.24-alpine AS builder 

    #Definir el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar definiciones de dependencias
COPY src/go.mod ./
RUN go mod download

# Copiar codigo fuente
COPY src/*.go ./

# Compilar binario estatico optimizado (sin depuración ni CGO)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server .

# ------------------------------------------------------------------------------
# STAGE 2: Runtime Distroless / Unprivileged User (Hardened)
# ------------------------------------------------------------------------------
FROM alpine:3.20

# Crear usuario sin privilegios para evitar correr como root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar el binario compilado desde la etapa anterior
COPY --from=builder /app/server .

# Asignar propiedad del archivo al usuario no-root
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["./server"]