# Gleam Fullstack Master Skill

## 🛡️ MANDATORY VERIFICATION PROTOCOL (Read Every Turn)

To guarantee effectiveness and prevent skill-drift, you **MUST** follow these steps for every task:

1. **Self-Identification**: State which domain you are working on.
2. **Reference Declaration**: Before writing code, you **MUST** explicitly state: *"Reading [reference_file.md] and .impeccable.md to verify compliance."* and actually call `read_file` on them.
3. **Contract Check**: You **MUST** read `shared/src/shared/<domain>.gleam` before touching `client/` or `server/`.
4. **Design Audit**: Activate the `impeccable` skill for any UI task to ensure the "Soft & Humanist" aesthetic is preserved.
5. **Post-Implementation Audit**: After coding, verify against the "Anti-Patterns" section at the bottom of this skill.

---

## CRITICAL RULES

1. **NEVER edit `gleam.toml` manually**. Always use `gleam add <package>`.
2. **MANDATORY DESIGN SYSTEM & IMPECCABLE COMPLIANCE**: This project uses a built-in Design System based on **Tailwind CSS 4** and follows the **Soft & Humanist** aesthetic defined in `.impeccable.md`.
   - **IMPECCABLE FIRST**: You **MUST** consult the `impeccable` skill for all UI/UX decisions to avoid "AI slop" and ensure distinctive, production-grade design quality.
   - **CONTEXT FIRST**: Read `.impeccable.md` every time you touch the frontend. Adhere to the spacing (4px grid), typography (General Sans/DM Sans), and radii (12px rounded-md) defined there.
   - **COMPONENT FIRST**: Check `client/src/components/` before writing UI. If a component exists (Button, Input, card, etc.), you **MUST** use it.
   - **NO RAW HTML**: Do not use `html.button` or `html.input` directly.
   - **STYLE ENCAPSULATION**: Tailwind utility classes MUST live inside component files.

3. **MANDATORY MESSAGE NAMING**: Messages MUST be `Subject-Verb-Object` (e.g., `UserClickedSave`). Describe **WHAT HAPPENED**.
4. **CANONICAL ERROR SHAPE**: API errors MUST be `{"error": "Kind", "message": "text"}` via `error_response.handle()`.
5. **KEYED RENDERING**: ALWAYS use `keyed.element` for dynamic lists.

---

## Architecture & Workflow

1. **Research**: Map domains, read references, and **Design Context** (.impeccable.md).
2. **Contract First**: Define shared types/decoders in `shared/`.
3. **SQL First**: Write `.sql`, run `make generate-sql`.
4. **Vertical Domains**: Keep related logic together in domain folders.

---

## Decision Tree: "I need to..."

### Backend (API & Logic)
- ...name a new route → `references/route-naming.md`
- ...return an error from a handler → `references/error-responses.md`
- ...distinguish 400 vs 422 → `references/validation-errors.md`
- ...add pagination to a list endpoint → `references/pagination-hal.md`
- ...serialize timestamps or metadata → `references/json-serialization.md`
- ...merge multiple GET endpoints → `references/query-dispatch.md`
- ...dispatch POST by body type → `references/body-dispatch.md`
- ...serve SPA alongside API → `references/spa-routing.md`
- ...compose middleware → `references/middleware-composition.md`

### Frontend (Tailwind 4 + Impeccable Design)
- ...implement a new feature → Activate `impeccable craft` and follow `.impeccable.md`.
- ...setup SPA routing → `assets/examples/04-applications/01-routing`
- ...handle forms & validation → `assets/examples/02-inputs/04-forms`
- ...manage complex state → `references/architecture.md`
- ...ensure accessibility → Use semantic HTML in components and `impeccable` a11y guidelines.
- ...make API calls → `assets/examples/03-effects/01-http-requests`
- ...style a new component → Use OKLCH variables in `client/src/client.css` and follow **Warm Utility** principle.

---

## Technical Standards

### Accessibility (A11y)
- **ARIA**: Use `attribute.aria_expanded`, `attribute.role("button")`.
- **Keyboard**: Handle Enter/Space for activation and Arrow keys for navigation.
- **Inert**: Use `attribute.inert(True)` for collapsed content.

### API Middleware
- Compose with closures: `auth -> rate_limit -> handler`.
- Usage checks MUST be inside the database transaction.

---

## Anti-Patterns (Audit Checklist)
- [ ] Are messages imperative (e.g., `Save`)? -> **Fix to `UserClickedSave`**.
- [ ] Is SQL written as strings in Gleam? -> **Move to `.sql` files**.
- [ ] Is an API error returning a custom JSON shape? -> **Use `error_response.handle`**.
- [ ] Is `gleam.toml` edited manually? -> **Use `gleam add`**.
- [ ] Did you skip reading `.impeccable.md`? -> **Stop and read it now**.
- [ ] Are you using `html.button` instead of `components/button.gleam`? -> **Switch to Genesis components**.
- [ ] Does the UI feel "sterile" or "AI-generated"? -> **Apply Impeccable principles (Warm Utility, Soft radii)**.

## References
- `references/token-efficiency.md`: Research protocol.
- `references/architecture.md`: Vertical domains.
- `references/database.md`: SQL patterns.
- `.impeccable.md`: Project design context and principles.
- `client/src/client.css`: Source of truth for Tailwind 4 theme variables.
- `client/src/components/`: Design System component implementations.
