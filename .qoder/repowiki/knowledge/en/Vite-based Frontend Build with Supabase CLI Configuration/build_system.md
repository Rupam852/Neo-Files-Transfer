The Neo Files Transfer Platform utilizes a lightweight, script-free build system centered on **Vite** for the frontend and **Supabase CLI** conventions for the backend.

### Frontend Build System (Web Client)
- **Tooling**: The `web/` directory uses **Vite** as the primary build tool and development server. It is configured via `vite.config.js` to use the `@vitejs/plugin-react` plugin.
- **Scripts**: Build lifecycle commands are defined in `web/package.json`:
  - `npm run dev`: Starts the Vite development server on port 5173 with auto-open enabled.
  - `npm run build`: Compiles the React application into static assets (typically output to `dist/`).
  - `npm run preview`: Serves the production build locally for verification.
- **Styling Pipeline**: CSS processing is handled by **PostCSS** with **Tailwind CSS** and **Autoprefixer**, configured in `postcss.config.js` and `tailwind.config.js`.
- **Dependency Management**: Uses `npm` (evidenced by `package-lock.json`) for managing frontend dependencies.

### Backend Build & Configuration (Supabase)
- **Approach**: The backend relies on **Supabase Edge Functions** (Deno-based) rather than a traditional compiled backend. There are no explicit build scripts (e.g., `deno bundle`) in the repository; deployment is typically managed via the Supabase CLI (`supabase deploy`) which is not explicitly scripted in the repo root.
- **Configuration**: `supabase/config.toml` defines function-level security policies, specifically JWT verification requirements for each endpoint (e.g., `upload-file`, `download-file`).
- **Database Migrations**: Schema changes are managed via SQL migration files in `supabase/migrations/`, applied via the Supabase CLI.

### CI/CD and Containerization
- **Absence of CI/CD**: There are no CI/CD configuration files (e.g., `.github/workflows`, `.gitlab-ci.yml`) or containerization definitions (e.g., `Dockerfile`, `docker-compose.yml`) present in the repository.
- **Deployment**: Deployment appears to be manual or reliant on external, untracked scripts using the Supabase CLI and standard hosting for the static Vite build.

### Developer Conventions
- **Build Outputs**: The root `.gitignore` excludes `dist/`, `build/`, and `node_modules/`, ensuring only source code and configuration are versioned.
- **Environment Variables**: Local environment variables are stored in `web/.env` and excluded from version control via `.env.local` patterns in `.gitignore`.