# Gleam Fullstack Skill

Skill para generar y desarrollar aplicaciones fullstack type-safe con **Gleam + Lustre + Wisp + PostgreSQL**.

## Qué incluye

- **Scaffolding completo**: Genera monorepo con 3 paquetes (client/server/shared)
- **Arquitectura vertical**: Organización por dominios, no por capas técnicas
- **Type-safe SQL**: Squirrel genera código Gleam desde archivos .sql
- **Migraciones**: Cigogne para gestionar schema de PostgreSQL
- **Auth + Roles**: JWT authentication con sistema de permisos
- **Docker**: Multi-stage build + docker-compose para desarrollo
- **Makefile**: Comandos comunes de desarrollo

## Reglas Críticas

1. **NUNCA edites `gleam.toml` manualmente**. Usa siempre `gleam add <package>` para agregar dependencias.
2. **NUNCA cambies el formato de `gleam.toml`**. `gleam new` genera el formato estándar con secciones `[dependencies]` y `[dev-dependencies]`. `gleam add` preserva este formato.
3. **Usa `gleam add` con restricciones de versión**. Ejemplo: `gleam add lustre --'>=' 4.0.0 --'<' 5.0.0`
4. **Verifica el paquete Lustre** en `/home/svarona/Development/lustre/gleam.toml` para las versiones más actuales.

## Uso

### Crear nuevo proyecto

```bash
gleam run -m scripts/scaffold mi-app
cd mi-app
cp .env.example .env
make db          # Iniciar PostgreSQL
make setup       # Instalar deps y migraciones
make dev         # Iniciar servidores de desarrollo
```

### Agregar nuevo dominio

```bash
make domain NAME=billing
```

Esto crea:
- `server/src/billing/` con types, handlers, service, queries, tests
- `shared/src/shared/billing.gleam` con tipos compartidos
- `client/src/billing/views.gleam` con componentes frontend

### Comandos disponibles

| Comando | Descripción |
|---------|-------------|
| `make setup` | Setup inicial de desarrollo |
| `make dev` | Iniciar servidores con hot reload |
| `make migrate` | Aplicar migraciones |
| `make migrate-new NAME=x` | Crear nueva migración |
| `make generate-sql` | Regenerar queries type-safe |
| `make test` | Correr tests |
| `make build` | Build de producción |
| `make deploy` | Build imagen Docker |

## Arquitectura

```
mi-app/
├── client/          ← Lustre SPA (JavaScript)
├── server/          ← Wisp API (Erlang)
│   └── src/
│       ├── auth/    ← Dominio: autenticación
│       ├── billing/ ← Dominio: facturación
│       └── ...
└── shared/          ← Tipos compartidos
```

Cada dominio contiene todo lo necesario:
- `types.gleam` - Tipos y errores del dominio
- `service.gleam` - Lógica de negocio
- `handlers.gleam` - Endpoints HTTP
- `queries/` - Archivos SQL para Squirrel
- `tests/` - Tests del dominio

## Stack tecnológico

- **Frontend**: Lustre (framework SPA como Elm)
- **Backend**: Wisp (web framework) + Mist (HTTP server)
- **Database**: PostgreSQL + Pog (driver) + Squirrel (type-safe SQL)
- **Migrations**: Cigogne
- **Auth**: JWT stateless
- **Build**: Makefile + Docker

## Versiones Verificadas

| Paquete | Versión | Target |
|---------|---------|--------|
| `gleam_stdlib` | `>= 0.60.0 and < 2.0.0` | All |
| `gleam_erlang` | `>= 1.0.0 and < 2.0.0` | Server |
| `gleam_otp` | `>= 1.0.0 and < 2.0.0` | Server |
| `gleam_json` | `>= 1.0.0 and < 4.0.0` | All |
| `gleam_http` | `>= 3.7.2 and < 5.0.0` | All |
| `lustre` | `>= 4.0.0 and < 5.0.0` | Client |
| `lustre_dev_tools` | `>= 2.0.0 and < 3.0.0` | Client (dev) |
| `rsvp` | `>= 1.0.1 and < 2.0.0` | Client |
| `modem` | `>= 2.0.1 and < 3.0.0` | Client |
| `wisp` | `>= 1.0.0 and < 2.0.0` | Server |
| `mist` | `>= 6.0.2 and < 7.0.0` | Server |
| `pog` | `>= 1.0.0 and < 2.0.0` | Server |
| `squirrel` | `>= 1.0.0 and < 2.0.0` | Server (dev) |
| `cigogne` | `>= 1.0.0 and < 2.0.0` | Server (dev) |
| `envoy` | `>= 1.0.0 and < 2.0.0` | Server |

## Características

### Type-safe end-to-end
Los tipos se definen una sola vez en `shared/` y se usan en frontend y backend.

### SQL type-safe
Escribís SQL puro en archivos `.sql` y Squirrel genera funciones Gleam con decoders automáticos.

### Permisos basados en roles
Sistema de roles (Admin, Editor, Viewer) con permisos granulares:

```gleam
pub type Permission {
  CreateUsers
  EditContent
  DeleteContent
  ViewContent
}

pub fn has_permission(role: Role, permission: Permission) -> Bool {
  case role, permission {
    Admin, _ -> True
    Editor, EditContent -> True
    Viewer, ViewContent -> True
    _, _ -> False
  }
}
```

## Mejora Continua

Esta skill se auto-mejora siguiendo estos pasos:

1. **Verificar paquete Lustre**: Revisar `/home/svarona/Development/lustre/gleam.toml` para versiones actuales
2. **Verificar ejemplos**: Revisar `/home/svarona/Development/lustre/examples/` para patrones actualizados
3. **Actualizar constraints**: Cuando Lustre actualiza dependencias, actualizar la tabla de versiones
4. **Verificar scaffolding**: Después de actualizar versiones, correr `gleam run -m scripts/scaffold test-project`
5. **Preservar formato**: `gleam new` genera `[dependencies]` y `[dev-dependencies]`. Nunca convertir a inline tables.
6. **Usar gleam add exclusivamente**: Toda gestión de dependencias debe pasar por `gleam add`.

## Referencia de Ejemplos Lustre

Cuando enfrentes una situación específica en el frontend, consulta el ejemplo apropiado:

| Situación / Problema | Ejemplo a Consultar | Ubicación |
|---------------------|-------------------|----------|
| **Setup básico de app** | `01-hello-world` | `examples/01-basics/01-hello-world/` |
| **Agregar atributos HTML** | `02-attributes` | `examples/01-basics/02-attributes/` |
| **Organizar código de vistas** | `03-view-functions` | `examples/01-basics/03-view-functions/` |
| **Renderizado optimizado de listas** | `04-keyed-elements` | `examples/01-basics/04-keyed-elements/` |
| **Agrupar elementos sin wrapper** | `05-fragments` | `examples/01-basics/05-fragments/` |
| **Pasar datos de inicialización** | `06-flags` | `examples/01-basics/06-flags/` |
| **Manejo de inputs** | `01-controlled-inputs` | `examples/02-inputs/01-controlled-inputs/` |
| **Decodificadores de eventos custom** | `02-decoding-events` | `examples/02-inputs/02-decoding-events/` |
| **Debounce de inputs** | `03-debouncing` | `examples/02-inputs/03-debouncing/` |
| **Formularios** | `04-forms` | `examples/02-inputs/04-forms/` |
| **HTTP requests (API calls)** | `01-http-requests` | `examples/03-effects/01-http-requests/` |
| **Valores aleatorios** | `02-random` | `examples/03-effects/02-random/` |
| **Timers/Intervalos** | `03-timers` | `examples/03-effects/03-timers/` |
| **LocalStorage** | `04-local-storage` | `examples/03-effects/04-local-storage/` |
| **Manipulación directa del DOM** | `05-dom-effects` | `examples/03-effects/05-dom-effects/` |
| **Actualizaciones optimistas UI** | `06-optimistic-requests` | `examples/03-effects/06-optimistic-requests/` |
| **Routing SPA** | `01-routing` | `examples/04-applications/01-routing/` |
| **Hydration server-side** | `04-hydration` | `examples/04-applications/04-hydration/` |
| **Web Components** | `01-basic-setup` | `examples/05-components/01-basic-setup/` |
| **Atributos y eventos en componentes** | `02-attributes-and-events` | `examples/05-components/02-attributes-and-events/` |
| **Slots en componentes** | `03-slots` | `examples/05-components/03-slots/` |
| **Server components setup** | `01-basic-setup` | `examples/06-server-components/01-basic-setup/` |
| **Eventos en server components** | `02-attributes-and-events` | `examples/06-server-components/02-attributes-and-events/` |
| **Protección CSRF** | `06-csrf-protection` | `examples/06-server-components/06-csrf-protection/` |

### Cómo usar los ejemplos

1. **Siempre consulta el ejemplo primero** antes de implementar cualquier feature frontend
2. **Revisa el `gleam.toml`** del ejemplo para ver las versiones actuales, luego usa `gleam add <paquete> --'>=' <min> --'<' <max>` para instalar
3. **Estudia los patrones de import** - los ejemplos muestran los imports correctos
4. **Nota los patrones de efectos** - cada ejemplo demuestra la mejor práctica actual

**Ruta base**: `/home/svarona/Development/lustre/examples/`

## Referencias

- [Architecture Guide](references/architecture.md)
- [Database Guide](references/database.md)
- [Deployment Guide](references/deployment.md)
- [Lustre Package](file:///home/svarona/Development/lustre/gleam.toml) - Verdadero source of truth para versiones
- [Lustre Examples](file:///home/svarona/Development/lustre/examples/) - Patrones y mejores prácticas

## License

MIT
