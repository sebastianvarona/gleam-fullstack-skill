#!/bin/bash
set -e

DOMAIN_NAME=$1

if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: gleam run -m scripts/new_domain <domain-name>"
  exit 1
fi

echo "Creating new domain: $DOMAIN_NAME"

# Create server domain structure
mkdir -p server/src/$DOMAIN_NAME/queries
mkdir -p server/src/$DOMAIN_NAME/tests
mkdir -p client/src/$DOMAIN_NAME

# Create server types template
cat > server/src/$DOMAIN_NAME/types.gleam << EOF
// Domain types for $DOMAIN_NAME

import gleam/dynamic/decode

pub type ${DOMAIN_NAME^}Error {
  NotFound
  ValidationError(String)
  DatabaseError(String)
}

// Add your domain types here
EOF

# Create server service template
cat > server/src/$DOMAIN_NAME/service.gleam << EOF
import gleam/result
import pog
import $DOMAIN_NAME/types

// Add your business logic here
// Use functions from $DOMAIN_NAME/queries/sql after running 'make generate-sql'
EOF

# Create server handlers template
cat > server/src/$DOMAIN_NAME/handlers.gleam << EOF
import gleam/http.{Get, Post, Put, Delete}
import gleam/json
import pog
import wisp.{type Request, type Response}

pub fn router(req: Request, db: pog.Connection) -> Response {
  case req.method, wisp.path_segments(req) {
    // Add your routes here
    // Example:
    // Get, ["api", "$DOMAIN_NAME"] -> list_items(req, db)
    // Post, ["api", "$DOMAIN_NAME"] -> create_item(req, db)
    // Get, ["api", "$DOMAIN_NAME", id] -> get_item(req, db, id)
    // Put, ["api", "$DOMAIN_NAME", id] -> update_item(req, db, id)
    // Delete, ["api", "$DOMAIN_NAME", id] -> delete_item(req, db, id)
    _, _ -> wisp.not_found()
  }
}
EOF

# Create shared types template
cat > shared/src/shared/$DOMAIN_NAME.gleam << EOF
import gleam/json
import gleam/dynamic/decode

// Add your shared types here
// These will be used by both client and server

// Example:
// pub type ${DOMAIN_NAME^} {
//   ${DOMAIN_NAME^}(id: Int, name: String)
// }
EOF

# Create client views template
cat > client/src/$DOMAIN_NAME/views.gleam << EOF
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// Add your frontend components here

// Example view function:
// pub fn list_view(items: List(${DOMAIN_NAME^})) -> Element(Msg) {
//   html.div([attribute.class("container")], [
//     html.h1([], [html.text("${DOMAIN_NAME^} List")]),
//     // Add your view code here
//   ])
// }
EOF

# Create example query template
cat > server/src/$DOMAIN_NAME/queries/get_by_id.sql << EOF
-- Get a ${DOMAIN_NAME} by id
-- Replace with your actual table and columns

-- Example:
-- SELECT id, name, created_at
-- FROM ${DOMAIN_NAME}s
-- WHERE id = \$1;
EOF

cat > server/src/$DOMAIN_NAME/queries/create.sql << EOF
-- Create a new ${DOMAIN_NAME}
-- Replace with your actual table and columns

-- Example:
-- INSERT INTO ${DOMAIN_NAME}s (name)
-- VALUES (\$1)
-- RETURNING id, name, created_at;
EOF

# Create test template
cat > server/src/$DOMAIN_NAME/tests/${DOMAIN_NAME}_test.gleam << EOF
import gleeunit
import gleeunit/should
import $DOMAIN_NAME/types

pub fn main() {
  gleeunit.main()
}

// Add your tests here
pub fn error_types_test() {
  types.NotFound
  |> should.equal(types.NotFound)
}
EOF

echo "✅ Domain '$DOMAIN_NAME' created successfully!"
echo ""
echo "Files created:"
echo "  server/src/$DOMAIN_NAME/types.gleam"
echo "  server/src/$DOMAIN_NAME/service.gleam"
echo "  server/src/$DOMAIN_NAME/handlers.gleam"
echo "  server/src/$DOMAIN_NAME/queries/get_by_id.sql"
echo "  server/src/$DOMAIN_NAME/queries/create.sql"
echo "  server/src/$DOMAIN_NAME/tests/${DOMAIN_NAME}_test.gleam"
echo "  shared/src/shared/$DOMAIN_NAME.gleam"
echo "  client/src/$DOMAIN_NAME/views.gleam"
echo ""
echo "CRITICAL: MANDATORY INTEGRATION CHECKLIST"
echo "----------------------------------------"
echo "1. [ ] Define shared types and decoders in shared/src/shared/$DOMAIN_NAME.gleam"
echo "2. [ ] REGISTER DOMAIN in server/src/server.gleam:"
echo "       import $DOMAIN_NAME/handlers as ${DOMAIN_NAME}_handlers"
echo "       In handle_request add: _, [\"api\", \"$DOMAIN_NAME\", ..] -> ${DOMAIN_NAME}_handlers.router(req, db)"
echo "3. [ ] REGISTER DOMAIN in client/src/client.gleam (import views and add to main Model/Msg/Update/View)"
echo "4. [ ] Create database migration: make migrate-new NAME=create_${DOMAIN_NAME}s"
echo "5. [ ] Write SQL queries in server/src/$DOMAIN_NAME/queries/"
echo "6. [ ] Run: make generate-sql"
echo "7. [ ] Implement business logic in server/src/$DOMAIN_NAME/service.gleam"
echo "----------------------------------------"
