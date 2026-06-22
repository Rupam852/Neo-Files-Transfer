The Neo Files Transfer Platform employs a dual-layer configuration strategy, separating backend infrastructure settings from frontend runtime environment variables.

### Backend Configuration (Supabase)
The backend relies on the Supabase CLI's standard `supabase/config.toml` for local development and Edge Function deployment settings. 
- **Edge Function Security**: The primary configuration in `config.toml` defines JWT verification requirements for each Edge Function (`validate-folder`, `upload-file`, etc.). Most functions enforce `verify_jwt = true`, while public-facing functions like `download-file` are explicitly configured with `verify_jwt = false`.
- **Database Schema**: Initial database structure and Row Level Security (RLS) policies are managed via SQL migration files located in `supabase/migrations/`.

### Frontend Configuration (Vite + React)
The web client uses Vite's environment variable system to manage runtime configuration, allowing for different settings across development and production environments.
- **Environment Variables**: Core secrets and endpoints are stored in `.env` using the `VITE_` prefix, which exposes them to the client-side bundle. Key variables include:
  - `VITE_SUPABASE_URL`: The Supabase project endpoint.
  - `VITE_SUPABASE_ANON_KEY`: The public anonymous key for client-side Supabase interactions.
  - `VITE_APP_URL`: The base URL of the application, used for generating shareable links and OAuth redirects.
- **Configuration Loading**: 
  - The `src/services/supabase.js` module initializes the Supabase client by reading `import.meta.env.VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` at module load time.
  - Utility functions in `src/utils/helpers.js` and various page components access `import.meta.env.VITE_APP_URL` or construct API endpoints dynamically using `import.meta.env.VITE_SUPABASE_URL`.
- **Build Tooling**: `vite.config.js` handles basic server configuration (port `5173`, auto-open) but delegates environment loading to Vite's default behavior.

### Developer Conventions
1. **Prefix Requirement**: All frontend environment variables must be prefixed with `VITE_` to be accessible in the browser via `import.meta.env`.
2. **Secrets Management**: Sensitive keys (like the Supabase Anon Key) are committed to `.env` in this repository structure, but in a production CI/CD pipeline, these should be injected via secure secret managers rather than hardcoded.
3. **Dynamic Endpoint Construction**: When calling Edge Functions, developers consistently construct URLs using `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/<function-name>` to ensure environment-agnostic routing.