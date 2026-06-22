The Neo Files Transfer Platform employs a utility-first styling approach using **Tailwind CSS** (v3.4) as its primary styling engine. The system is configured via `tailwind.config.js` and processed through PostCSS.

### Core Styling System
- **Framework**: Tailwind CSS integrated with Vite.
- **Configuration**: Defined in `web/tailwind.config.js`, scanning all JSX/TSX files for class usage.
- **Global Styles**: `web/src/index.css` imports Tailwind's base, components, and utilities layers. It also defines global resets and custom scrollbar styling.

### Design Tokens & Theme
- **Color Palette**: A custom `primary` color scale (50-900) is defined, mapping to blue hues (`#3b82f6` at 500). This is used for branding, buttons, and interactive elements.
- **Typography**: The font stack prioritizes 'Inter' and 'Roboto', falling back to sans-serif. Body text uses a dark slate (`#1e293b`) on a light background (`#f8fafc`).
- **Component Classes**: Reusable UI patterns are abstracted into custom component classes within `index.css` using `@layer components`:
  - `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-success`: Standardized button styles with hover states and transitions.
  - `.input-field`: Consistent form input styling with focus rings.
  - `.card`: White background, rounded corners, subtle shadow, and border for content containers.

### Conventions & Patterns
- **Utility-First**: Most layout and spacing are handled via inline Tailwind utility classes (e.g., `flex`, `gap-4`, `p-6`).
- **Semantic Abstraction**: Complex interactive states (buttons, inputs) are moved to semantic classes in CSS to reduce HTML clutter and ensure consistency.
- **Responsive Design**: Mobile-first responsive prefixes (e.g., `sm:px-6`, `md:grid-cols-3`) are used throughout layouts.
- **Iconography**: Uses `lucide-react` for consistent, lightweight SVG icons.
- **Feedback**: Uses `react-hot-toast` for non-blocking user notifications.