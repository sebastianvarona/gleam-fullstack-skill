#!/bin/bash
set -e

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: gleam run -m scripts/scaffold <project-name>"
  exit 1
fi

echo "Creating Gleam fullstack project: $PROJECT_NAME"

# Create project directory
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create shared package
echo "Creating shared package..."
gleam new shared
cd shared
# Add dependencies using gleam add (NEVER edit gleam.toml manually)
gleam add gleam_json
cd ..

# Create server package
echo "Creating server package..."
gleam new server
cd server
# Add server dependencies using gleam add ONLY
gleam add wisp
gleam add mist
gleam add pog
gleam add gleam_json
gleam add gleam_erlang
gleam add gleam_otp
gleam add envoy
gleam add gleam_http
# Add local shared dependency
gleam add shared --path ../shared
# Add dev dependencies
gleam add --dev squirrel
gleam add --dev cigogne
cd ..

# Create client package with JavaScript target
echo "Creating client package..."
gleam new --target=javascript client
cd client
# Add client dependencies using gleam add ONLY
gleam add lustre
gleam add rsvp
gleam add gleam_json
gleam add gleam_http
gleam add modem
# Add local shared dependency
gleam add shared --path ../shared
# Add dev dependencies
gleam add --dev lustre_dev_tools
cd ..

# Create migrations directory
mkdir -p server/migrations

# Create middleware directory
mkdir -p server/src/middleware

# Create auth domain
mkdir -p server/src/auth/queries
mkdir -p server/src/auth/tests
mkdir -p client/src/auth

# Create shared auth types
cat > shared/src/shared/auth.gleam << 'EOF'
import gleam/json
import gleam/dynamic/decode

pub type User {
  User(id: Int, email: String, role: Role)
}

pub type Role {
  Admin
  Editor
  Viewer
}

pub type Permission {
  CreateUsers
  EditUsers
  DeleteUsers
  EditContent
  DeleteContent
  ViewContent
}

pub type AuthRequest {
  AuthRequest(email: String, password: String)
}

pub type AuthResponse {
  AuthResponse(token: String, user: User)
}

pub fn user_to_json(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("role", role_to_json(user.role)),
  ])
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", role_decoder())
  decode.success(User(id:, email:, role:))
}

pub fn role_to_json(role: Role) -> json.Json {
  json.string(case role {
    Admin -> "admin"
    Editor -> "editor"
    Viewer -> "viewer"
  })
}

pub fn role_decoder() -> decode.Decoder(Role) {
  decode.string
  |> decode.map(fn(role) {
    case role {
      "admin" -> Admin
      "editor" -> Editor
      _ -> Viewer
    }
  })
}

pub fn has_permission(role: Role, permission: Permission) -> Bool {
  case role, permission {
    Admin, _ -> True
    Editor, EditContent -> True
    Editor, DeleteContent -> True
    Editor, ViewContent -> True
    Viewer, ViewContent -> True
    _, _ -> False
  }
}

pub fn role_from_string(role: String) -> Role {
  case role {
    "admin" -> Admin
    "editor" -> Editor
    _ -> Viewer
  }
}
EOF

# Create server auth types
cat > server/src/auth/types.gleam << 'EOF'
import gleam/dynamic/decode
import shared/auth.{type Role, type Permission}

pub type AuthError {
  InvalidCredentials
  UserNotFound
  EmailAlreadyExists
  InvalidToken
  InsufficientPermissions(Permission)
}

pub type Claims {
  Claims(user_id: Int, email: String, role: Role, exp: Int)
}

pub fn claims_decoder() -> decode.Decoder(Claims) {
  use user_id <- decode.field("user_id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", auth.role_decoder())
  use exp <- decode.field("exp", decode.int)
  decode.success(Claims(user_id:, email:, role:, exp:))
}
EOF

# Create auth queries
cat > server/src/auth/queries/get_user.sql << 'EOF'
-- Get a user by email
select id, email, role
from users
where email = $1;
EOF

cat > server/src/auth/queries/create_user.sql << 'EOF'
-- Create a new user
insert into users (email, password_hash, role)
values ($1, $2, $3)
returning id, email, role;
EOF

# Create auth service
cat > server/src/auth/service.gleam << 'EOF'
import gleam/result
import pog
import shared/auth.{type Role, type User, User, has_permission}
import auth/types.{type AuthError, InvalidCredentials, UserNotFound, EmailAlreadyExists}
import auth/queries/sql

pub fn find_user(db: pog.Connection, email: String) -> Result(User, AuthError) {
  case sql.get_user(db, email) {
    Ok(pog.Returned(_, [row])) -> Ok(User(id: row.id, email: row.email, role: shared.auth.role_from_string(row.role)))
    Ok(pog.Returned(_, [])) -> Error(UserNotFound)
    _ -> Error(UserNotFound)
  }
}

pub fn create_user(
  db: pog.Connection,
  email: String,
  password_hash: String,
  role: Role,
) -> Result(User, AuthError) {
  let role_str = case role {
    shared.auth.Admin -> "admin"
    shared.auth.Editor -> "editor"
    shared.auth.Viewer -> "viewer"
  }
  
  case sql.create_user(db, email, password_hash, role_str) {
    Ok(pog.Returned(_, [row])) -> Ok(User(id: row.id, email: row.email, role: shared.auth.role_from_string(row.role)))
    Error(pog.ConstraintViolated(_, _, _)) -> Error(EmailAlreadyExists)
    _ -> Error(EmailAlreadyExists)
  }
}

pub fn verify_password(hash: String, password: String) -> Bool {
  // In production, use bcrypt or Argon2
  // This is a placeholder for demonstration
  hash == password
}
EOF

# Create auth handlers
cat > server/src/auth/handlers.gleam << 'EOF'
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import pog
import wisp.{type Request, type Response}
import shared/auth.{type AuthRequest, type AuthResponse, AuthResponse, User}
import auth/types.{type AuthError, InvalidCredentials, InsufficientPermissions}
import auth/service

pub fn router(req: Request, db: pog.Connection, secret: String) -> Response {
  case req.method, wisp.path_segments(req) {
    Post, ["api", "auth", "login"] -> handle_login(req, db, secret)
    Post, ["api", "auth", "register"] -> handle_register(req, db, secret)
    Get, ["api", "auth", "me"] -> handle_me(req, db, secret)
    _, _ -> wisp.not_found()
  }
}

fn handle_login(req: Request, db: pog.Connection, secret: String) -> Response {
  use json <- wisp.require_json(req)
  
  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(shared.auth.AuthRequest(email:, password:))
  }
  
  case decode.run(json, decoder) {
    Ok(auth_req) -> {
      case service.find_user(db, auth_req.email) {
        Ok(user) -> {
          case service.verify_password(user.password_hash, auth_req.password) {
            True -> {
              let token = create_token(user, secret)
              let response = AuthResponse(token:, user:)
              wisp.json_response(
                json.object([
                  #("token", json.string(response.token)),
                  #("user", shared.auth.user_to_json(response.user)),
                ])
                |> json.to_string,
                200,
              )
            }
            False -> wisp.unauthorized()
          }
        }
        Error(_) -> wisp.unauthorized()
      }
    }
    Error(_) -> wisp.bad_request("Invalid request body")
  }
}

fn handle_register(req: Request, db: pog.Connection, secret: String) -> Response {
  use json <- wisp.require_json(req)
  
  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(#(email, password))
  }
  
  case decode.run(json, decoder) {
    Ok(#(email, password)) -> {
      // In production, hash the password properly
      let password_hash = password
      
      case service.create_user(db, email, password_hash, shared.auth.Viewer) {
        Ok(user) -> {
          let token = create_token(user, secret)
          wisp.json_response(
            json.object([
              #("token", json.string(token)),
              #("user", shared.auth.user_to_json(user)),
            ])
            |> json.to_string,
            201,
          )
        }
        Error(_) -> wisp.bad_request("Email already exists")
      }
    }
    Error(_) -> wisp.bad_request("Invalid request body")
  }
}

fn handle_me(req: Request, db: pog.Connection, secret: String) -> Response {
  case extract_user_from_token(req, secret) {
    Ok(user) -> {
      wisp.json_response(
        shared.auth.user_to_json(user)
        |> json.to_string,
        200,
      )
    }
    Error(_) -> wisp.unauthorized()
  }
}

fn create_token(user: shared.auth.User, secret: String) -> String {
  // Use a JWT library in production
  // This is a simplified placeholder
  "jwt_token_placeholder"
}

fn extract_user_from_token(req: Request, secret: String) -> Result(shared.auth.User, Nil) {
  // Extract and verify JWT from Authorization header
  Error(Nil)
}
EOF

# Create middleware
cat > server/src/middleware/cors.gleam << 'EOF'
import wisp.{type Request, type Response}

pub fn middleware(req: Request, next: fn() -> Response) -> Response {
  let response = next()
  
  response
  |> wisp.set_header("access-control-allow-origin", "*")
  |> wisp.set_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
  |> wisp.set_header("access-control-allow-headers", "content-type, authorization")
}
EOF

cat > server/src/middleware/auth.gleam << 'EOF'
import wisp.{type Request, type Response}
import shared/auth.{type Role, type Permission, has_permission}

pub fn require_auth(req: Request, ctx: Context, next: fn(Request, Context) -> Response) -> Response {
  case extract_token(req) {
    Ok(token) -> {
      case verify_jwt(token, ctx.secret) {
        Ok(claims) -> next(req, Context(..ctx, user: Some(claims)))
        Error(_) -> wisp.unauthorized()
      }
    }
    Error(_) -> wisp.unauthorized()
  }
}

pub fn require_permission(permission: Permission, next: fn() -> Response) -> Response {
  fn(req: Request, ctx: Context) {
    case ctx.user {
      Some(claims) -> {
        case has_permission(claims.role, permission) {
          True -> next()
          False -> wisp.forbidden()
        }
      }
      None -> wisp.unauthorized()
    }
  }
}

fn extract_token(req: Request) -> Result(String, Nil) {
  case wisp.get_header(req, "authorization") {
    Ok("Bearer " <> token) -> Ok(token)
    _ -> Error(Nil)
  }
}

fn verify_jwt(token: String, secret: String) -> Result(shared.auth.Claims, Nil) {
  // Implement JWT verification
  Error(Nil)
}

pub type Context {
  Context(secret: String, user: Option(shared.auth.Claims))
}
EOF

# Create main server file
cat > server/src/server.gleam << 'EOF'
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import mist
import pog
import wisp.{type Request, type Response}
import wisp/wisp_mist
import auth/handlers as auth_handlers
import middleware/cors

pub fn main() {
  wisp.configure_logger()
  
  let secret = case envoy.get("JWT_SECRET") {
    Ok(secret) -> secret
    Error(_) -> "default-secret-change-in-production"
  }
  
  let db_config =
    pog.default_config(pool_name)
    |> pog.host(case envoy.get("DB_HOST") { Ok(h) -> h Error(_) -> "localhost" })
    |> pog.database(case envoy.get("DB_NAME") { Ok(n) -> n Error(_) -> "myapp" })
    |> pog.user(case envoy.get("DB_USER") { Ok(u) -> u Error(_) -> "postgres" })
    |> pog.password(case envoy.get("DB_PASSWORD") { Ok(p) -> p Error(_) -> "" })
    |> pog.pool_size(10)
  
  let assert Ok(db) = pog.start_pool(db_config)
  
  let static_dir = case wisp.priv_directory("server") {
    Ok(priv) -> priv <> "/static"
    Error(_) -> "/tmp/static"
  }
  
  let handler = handle_request(_, db, secret, static_dir)
  
  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret)
    |> mist.new
    |> mist.port(3000)
    |> mist.start
  
  process.sleep_forever()
}

fn handle_request(req: Request, db, secret, static_dir) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: static_dir)
  use <- cors.middleware(req)
  
  case req.method, wisp.path_segments(req) {
    _, ["api", "auth", ..] -> auth_handlers.router(req, db, secret)
    Get, _ -> serve_index()
    _, _ -> wisp.not_found()
  }
}

fn serve_index() -> Response {
  let html = "<!DOCTYPE html>
<html>
<head>
  <meta charset=\"UTF-8\">
  <title>My App</title>
  <script type=\"module\" src=\"/static/client.js\"></script>
</head>
<body>
  <div id=\"app\"></div>
</body>
</html>"
  
  wisp.html_response(html, 200)
}
EOF

# Create first migration
cat > server/migrations/20250421000001_create_users.sql << 'EOF'
-- Create users table with roles

CREATE TYPE user_role AS ENUM ('admin', 'editor', 'viewer');

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role user_role NOT NULL DEFAULT 'viewer',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
EOF

# Create Makefile
cat > Makefile << 'EOF'
.PHONY: setup dev migrate migrate-new generate-sql test test-watch build deploy domain

setup:
	@echo "Setting up development environment..."
	cd shared && gleam deps download
	cd server && gleam deps download
	cd client && gleam deps download
	@echo "Creating database..."
	createdb myapp || true
	@echo "Applying migrations..."
	cd server && gleam run -m cigogne migrate up
	@echo "Generating SQL queries..."
	cd server && gleam run -m squirrel
	@echo "Setup complete!"

dev:
	@echo "Starting development servers..."
	@echo "Make sure PostgreSQL is running (use 'make db' if using Docker)"
	cd server && gleam run &
	cd client && gleam run -m lustre/dev start

db:
	docker-compose up -d postgres

migrate:
	cd server && gleam run -m cigogne migrate up

migrate-new:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make migrate-new NAME=description"; \
		exit 1; \
	fi
	cd server && gleam run -m cigogne new $(NAME)

generate-sql:
	cd server && gleam run -m squirrel

test:
	cd shared && gleam test
	cd server && gleam test
	cd client && gleam test

test-watch:
	cd shared && gleam test --watch &
	cd server && gleam test --watch &
	cd client && gleam test --watch

build:
	@echo "Building for production..."
	cd client && gleam run -m lustre/dev build --minify --outdir=../server/priv/static
	cd server && gleam build

deploy:
	make build
	docker build -t $(PROJECT_NAME) .

domain:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make domain NAME=my_domain"; \
		exit 1; \
	fi
	gleam run -m scripts/new_domain $(NAME)

lint:
	cd shared && gleam format
	cd server && gleam format
	cd client && gleam format
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
# Build stage
FROM ghcr.io/gleam-lang/gleam:v1.6.0-erlang-alpine AS builder

WORKDIR /build

# Copy all packages
COPY shared ./shared
COPY server ./server
COPY client ./client

# Install dependencies using gleam add (or deps download)
RUN cd shared && gleam deps download
RUN cd server && gleam deps download
RUN cd client && gleam deps download

# Build client
RUN cd client && gleam run -m lustre/dev build --minify --outdir=../server/priv/static

# Build server
RUN cd server && gleam build

# Runtime stage
FROM erlang:27-alpine

WORKDIR /app

# Copy built artifacts
COPY --from=builder /build/server/build/erlang-shipment .

ENV PORT=3000
EXPOSE 3000

CMD ["./entrypoint.sh"]
EOF

# Create .env.example
cat > .env.example << 'EOF'
# Database
DATABASE_URL=postgres://postgres:postgres@localhost:5432/myapp
DB_HOST=localhost
DB_NAME=myapp
DB_USER=postgres
DB_PASSWORD=postgres

# JWT
JWT_SECRET=change-me-in-production

# Server
PORT=3000
POOL_SIZE=10
LOG_LEVEL=info
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Gleam
build/
*.ez

# Generated files
server/src/**/sql.gleam

# Environment
.env

# Database
*.db

# IDE
.vscode/
.idea/

# OS
.DS_Store
EOF

# Create client main file
cat > client/src/client.gleam << 'EOF'
import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp
import shared/auth.{type User, type Role, User, Admin, Editor, Viewer}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  
  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    user: Option(User),
    email: String,
    password: String,
    error: Option(String),
    loading: Bool,
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model(user: None, email: "", password: "", error: None, loading: False), effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserChangedEmail(String)
  UserChangedPassword(String)
  UserClickedLogin
  LoginResponse(Result(String, String))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedEmail(email) -> #(Model(..model, email:, error: None), effect.none())
    UserChangedPassword(password) -> #(Model(..model, password:, error: None), effect.none())
    UserClickedLogin -> {
      case model.email, model.password {
        "", _ | _, "" -> #(Model(..model, error: Some("Please fill in all fields")), effect.none())
        _, _ -> #(Model(..model, loading: True, error: None), login(model.email, model.password))
      }
    }
    LoginResponse(Ok(token)) -> {
      // Store token and load user
      #(Model(..model, loading: False), effect.none())
    }
    LoginResponse(Error(error)) -> {
      #(Model(..model, loading: False, error: Some(error)), effect.none())
    }
  }
}

fn login(email: String, password: String) -> Effect(Msg) {
  let body = json.object([
    #("email", json.string(email)),
    #("password", json.string(password)),
  ])
  
  rsvp.post(
    "/api/auth/login",
    json.to_string(body),
    rsvp.expect_json(
      fn() {
        use token <- decode.field("token", decode.string)
        decode.success(token)
      },
      fn(result) {
        case result {
          Ok(token) -> LoginResponse(Ok(token))
          Error(_) -> LoginResponse(Error("Invalid credentials"))
        }
      },
    ),
  )
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("container")], [
    html.h1([], [html.text("Login")]),
    case model.error {
      Some(error) -> html.div([attribute.class("error")], [html.text(error)])
      None -> element.none()
    },
    html.div([attribute.class("form-group")], [
      html.label([], [html.text("Email")]),
      html.input([
        attribute.type_("email"),
        attribute.value(model.email),
        event.on_input(UserChangedEmail),
      ]),
    ]),
    html.div([attribute.class("form-group")], [
      html.label([], [html.text("Password")]),
      html.input([
        attribute.type_("password"),
        attribute.value(model.password),
        event.on_input(UserChangedPassword),
      ]),
    ]),
    html.button(
      [event.on_click(UserClickedLogin), attribute.disabled(model.loading)],
      [html.text(case model.loading {
        True -> "Loading..."
        False -> "Login"
      })],
    ),
  ])
}
EOF

echo "✅ Project scaffolded successfully!"
echo ""
echo "Next steps:"
echo "1. cd $PROJECT_NAME"
echo "2. cp .env.example .env"
echo "3. make db          # Start PostgreSQL"
echo "4. make setup       # Install deps and run migrations"
echo "5. make dev         # Start development servers"
