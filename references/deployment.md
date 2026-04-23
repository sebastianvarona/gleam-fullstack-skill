# Deployment Guide

## Docker Deployment

### Multi-Stage Dockerfile

The included Dockerfile uses multi-stage builds for minimal image size:

```dockerfile
# Build stage - includes Gleam compiler and dependencies
FROM ghcr.io/gleam-lang/gleam:v1.4.0-erlang-alpine AS builder

WORKDIR /build

COPY shared ./shared
COPY server ./server
COPY client ./client

RUN cd shared && gleam deps download
RUN cd server && gleam deps download
RUN cd client && gleam deps download

# Build client assets
RUN cd client && gleam run -m lustre/dev build --minify --outdir=../server/priv/static

# Build server
RUN cd server && gleam build

# Runtime stage - minimal Erlang runtime
FROM erlang:26-alpine

WORKDIR /app

COPY --from=builder /build/server/build/erlang-shipment .

ENV PORT=3000
EXPOSE 3000

CMD ["./entrypoint.sh"]
```

### Building and Running

```bash
make deploy          # Build Docker image
docker build -t myapp .

# Run locally
docker run -p 3000:3000 \
  -e DATABASE_URL=postgres://... \
  -e JWT_SECRET=... \
  myapp

# Run with docker-compose
docker-compose up -d
```

### Docker Compose for Production

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres:5432/myapp
      JWT_SECRET: ${JWT_SECRET}
      PORT: 3000
      POOL_SIZE: 20
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 512M

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
```

## Fly.io Deployment

Fly.io is well-suited for Gleam/Erlang applications.

### Setup

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Create app
fly apps create my-gleam-app
```

### fly.toml

```toml
app = "my-gleam-app"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8080"
  POOL_SIZE = "10"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1
```

### Deploy

```bash
# Set secrets
fly secrets set DATABASE_URL=postgres://... JWT_SECRET=...

# Deploy
fly deploy

# View logs
fly logs

# Scale up
fly scale count 2
```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/db` |
| `JWT_SECRET` | Secret for JWT signing | `super-secret-key` |
| `PORT` | HTTP port | `3000` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `POOL_SIZE` | DB connection pool size | `10` |
| `LOG_LEVEL` | Logging level | `info` |
| `DB_HOST` | Database host (if not using URL) | `localhost` |
| `DB_NAME` | Database name | `myapp` |
| `DB_USER` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `` |

### Loading from .env

Use `envoy` to read environment variables:

```gleam
import envoy

pub fn get_config() {
  let database_url = case envoy.get("DATABASE_URL") {
    Ok(url) -> url
    Error(_) -> build_connection_string()
  }
  
  let jwt_secret = case envoy.get("JWT_SECRET") {
    Ok(secret) -> secret
    Error(_) -> panic as "JWT_SECRET is required"
  }
  
  Config(database_url:, jwt_secret:)
}
```

## SSL/TLS

### PostgreSQL SSL

```gleam
let config =
  pog.default_config(pool_name)
  |> pog.ssl_mode(pog.SslVerified)  // or SslUnverified for dev
```

### HTTPS with Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    location / {
        proxy_pass http://app:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Health Checks

Add a health check endpoint:

```gleam
fn handle_request(req: Request) -> Response {
  case wisp.path_segments(req) {
    ["health"] -> wisp.ok()  // Returns 200 if server is up
    _ -> router(req)
  }
}
```

## Monitoring

### Logging

Wisp provides request logging out of the box:

```gleam
pub fn handle_request(req: Request) -> Response {
  use <- wisp.log_request(req)
  // ...
}
```

Configure log level via environment:

```bash
LOG_LEVEL=debug   # Most verbose
LOG_LEVEL=info    # Default
LOG_LEVEL=warn    # Warnings and errors only
LOG_LEVEL=error   # Errors only
```

### Metrics

Add custom metrics using Erlang's built-in tools:

```gleam
import gleam/erlang/process

pub fn track_request_duration(duration_ms: Int) {
  // Send to metrics collector
  process.send(metrics_pid, RequestDuration(duration_ms))
}
```

### Error Tracking

Log errors with context:

```gleam
pub fn handle_error(error: AppError) {
  let context = #(
    error_type: error.type,
    user_id: error.user_id,
    timestamp: now(),
  )
  
  log.error("Application error", context)
  
  // Send to error tracking service
  // sentry.capture_exception(error, context)
}
```

## Database Migrations in Production

### Strategy 1: Run Migrations Before Deploy

```bash
# In CI/CD pipeline
cd server
gleam run -m cigogne migrate up

# Then deploy
fly deploy
```

### Strategy 2: Init Container

```yaml
# docker-compose.yml
services:
  migrate:
    build: .
    command: ["gleam", "run", "-m", "cigogne", "migrate", "up"]
    environment:
      DATABASE_URL: postgres://...
    depends_on:
      - postgres
    restart: on-failure

  app:
    build: .
    depends_on:
      migrate:
        condition: service_completed_successfully
```

### Strategy 3: Built-in Migration on Startup

```gleam
pub fn main() {
  // Run migrations before starting server
  let assert Ok(_) = run_migrations()
  
  // Start server
  start_server()
}
```

## Backup and Recovery

### PostgreSQL Backups

```bash
# Manual backup
pg_dump myapp > backup.sql

# Restore
psql myapp < backup.sql

# Automated with cron
0 2 * * * pg_dump myapp | gzip > /backups/myapp-$(date +%Y%m%d).sql.gz
```

### Docker Volume Backups

```bash
# Backup volume
docker run --rm -v myapp_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .

# Restore volume
docker run --rm -v myapp_postgres_data:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/postgres-backup.tar.gz"
```

## Scaling

### Horizontal Scaling

Run multiple instances behind a load balancer:

```yaml
# docker-compose.yml
services:
  app:
    build: .
    deploy:
      replicas: 3
    environment:
      DATABASE_URL: ...
      POOL_SIZE: 5  # Reduce pool size per instance
```

### Database Read Replicas

For read-heavy workloads:

```gleam
// Read from replica
let read_db = pog.named_connection(read_pool_name)

// Write to primary
let write_db = pog.named_connection(write_pool_name)
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs myapp

# Check environment variables
docker exec myapp env

# Test database connection
docker exec myapp gleam run -m test_db_connection
```

### High Memory Usage

```bash
# Check memory usage
docker stats myapp

# Reduce pool size
POOL_SIZE=5

# Add memory limits
docker run -m 256m myapp
```

### Database Connection Issues

```bash
# Check active connections
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check connection pool status
# Add to your app: log pool stats periodically
```
