# Architecture Guide

## Vertical vs Horizontal Architecture

### Traditional (Horizontal - Anti-pattern)

```
controllers/
  user_controller.gleam
  post_controller.gleam
models/
  user.gleam
  post.gleam
views/
  user_view.gleam
  post_view.gleam
```

Problems:
- Changes require touching multiple directories
- No clear ownership of features
- Hard to understand a feature by looking at one place
- Merge conflicts between teams working on different features

### Vertical (Recommended)

```
auth/
  types.gleam
  handlers.gleam
  service.gleam
  queries/
  tests/
billing/
  types.gleam
  handlers.gleam
  service.gleam
  queries/
  tests/
```

Benefits:
- Everything related to a domain is in one place
- Easy to understand a feature end-to-end
- Teams can own entire domains
- Changes are localized

## Domain Structure

Each domain folder contains:

```
domain_name/
├── types.gleam       # Domain types, errors, validation
├── service.gleam     # Business logic, pure functions
├── handlers.gleam    # HTTP request/response handling
├── queries/          # SQL files for Squirrel
└── tests/            # Domain-specific tests
```

### Types Layer

Define all domain types and errors:

```gleam
pub type OrderError {
  InvalidItem(String)
  InsufficientStock(String, Int)
  PaymentFailed(String)
}

pub type Order {
  Order(
    id: Int,
    items: List(OrderItem),
    status: OrderStatus,
    total: Float,
  )
}

pub type OrderStatus {
  Pending
  Processing
  Shipped
  Delivered
  Cancelled
}
```

### Service Layer

Pure business logic, no HTTP or DB concerns:

```gleam
pub fn calculate_total(items: List(OrderItem)) -> Float {
  items
  |> list.map(fn(item) { item.price *. int.to_float(item.quantity) })
  |> float.sum
}

pub fn can_cancel(order: Order) -> Bool {
  case order.status {
    Pending -> True
    Processing -> True
    _ -> False
  }
}
```

### Handler Layer

HTTP-specific code, delegates to service:

```gleam
pub fn create_order(req: Request, db: pog.Connection) -> Response {
  use json <- wisp.require_json(req)
  use order_req <- parse_order_request(json)
  
  case service.create_order(db, order_req) {
    Ok(order) -> wisp.json_response(order_to_json(order), 201)
    Error(e) -> handle_order_error(e)
  }
}
```

## Shared Package

The `shared` package contains types used by both frontend and backend:

```gleam
// shared/src/shared/order.gleam
pub type Order {
  Order(id: Int, items: List(OrderItem), status: OrderStatus)
}

pub type OrderStatus {
  Pending
  Processing
  Shipped
}
```

Benefits:
- Frontend and backend always agree on data shapes
- Refactoring is safer - compiler catches mismatches
- No need to maintain separate type definitions

## Request Flow

```
HTTP Request
    |
    v
Handler (parse request, validate)
    |
    v
Service (business logic)
    |
    v
SQL Query (via Squirrel)
    |
    v
PostgreSQL
    |
    v
Handler (format response)
    |
    v
HTTP Response
```

## Error Handling

Use Result types throughout:

```gleam
pub fn process_order(db, request) -> Result(Order, OrderError) {
  use validated <- validate_request(request)
  use items <- fetch_items(db, validated.item_ids)
  use order <- create_order(db, validated, items)
  Ok(order)
}
```

Never use `panic` or `let assert` for expected errors.

## Middleware

Reusable middleware goes in `server/src/middleware/`:

- **CORS**: Cross-origin requests
- **Auth**: JWT validation
- **Logging**: Request/response logging
- **Rate limiting**: API throttling

Apply middleware in handlers using Gleam's `use` syntax:

```gleam
pub fn handle_request(req: Request) -> Response {
  use <- log_request(req)
  use <- cors.middleware(req)
  use req <- require_auth(req)
  
  // ... handle request
}
```

## Testing Strategy

### Unit Tests

Test pure functions in service layer:

```gleam
pub fn calculate_total_test() {
  let items = [
    OrderItem(price: 10.0, quantity: 2),
    OrderItem(price: 5.0, quantity: 1),
  ]
  
  order.calculate_total(items)
  |> should.equal(25.0)
}
```

### Integration Tests

Test full request handling:

```gleam
pub fn create_order_test() {
  let req = wisp.simulate_post("/api/orders", body)
  let response = handle_request(req, ctx)
  
  response.status
  |> should.equal(201)
}
```

### Test Organization

Keep tests close to the code they test:

```
auth/
  service.gleam
  tests/
    service_test.gleam
    handlers_test.gleam
```

## Naming Conventions

- **Files**: `snake_case.gleam`
- **Types**: `PascalCase`
- **Functions**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Modules**: Singular (`order`, not `orders`)

## Module Organization

Keep modules focused and cohesive:

```gleam
// Good: Focused module
// auth.gleam
pub type User { ... }
pub fn authenticate(...) { ... }
pub fn has_permission(...) { ... }

// Bad: Fragmented
// auth_types.gleam
// auth_service.gleam
// auth_utils.gleam
```

## Dependencies Between Domains

Minimize cross-domain dependencies. When necessary:

```gleam
// Instead of importing from other domains directly...
import billing/invoice

// Pass data through shared types
pub fn create_order_for_user(user: shared.auth.User, items: List(Item)) {
  // ...
}
```
