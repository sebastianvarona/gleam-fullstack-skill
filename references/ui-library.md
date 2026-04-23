# Lustre UI Library Guide

This reference document summarizes the usage of the `lustre-ui` library as the primary design system for the project.

## Core Philosophy
- **Accessibility First**: All components are designed with semantic HTML and ARIA attributes.
- **Backend-Friendly**: Opinionated visual design that reduces the need for custom CSS.
- **Themeable**: Highly customizable via CSS variables and the Gleam theme system.

## Theme System
The theme is defined in `lustre/ui/theme.gleam`. It uses design tokens for:
- **Fonts**: Heading, body, and code scales.
- **Space**: Defined in `rem` units (xs to xl_3).
- **Radius**: Consistent border radii across components.
- **Colors**: Light and Dark palettes with semantic scales (primary, success, warning, error, etc.).

### Applying a Theme
```gleam
import lustre/ui/theme

pub fn root_view() {
  theme.default()
  |> theme.with_primary_scale(my_custom_scale)
  |> theme.render()
}
```

## Available Components
Refer to `/home/svarona/.agents/skills/gleam-fullstack/assets/lustre-ui/` for source code:
- **Navigation**: `breadcrumb`, `combobox`.
- **Feedback**: `alert`, `badge`, `ticker`.
- **Inputs**: `button`, `checkbox`, `input`.
- **Layout**: `card`, `divider`, `accordion`.
- **Animation**: `reveal`, `tween`.

## Best Practices
1. **Prefer Semantic HTML**: Use the provided components instead of manual `html.div` with custom styles.
2. **Use Design Tokens**: When custom styling is needed, use theme variables (e.g., `theme.primary.solid_text`) instead of hardcoded hex values.
3. **Keyed Lists**: Always use `keyed.element` for dynamic collections of components.
4. **Message Naming**: UI events should be descriptive (e.g., `UserClickedAccordionTab`).
