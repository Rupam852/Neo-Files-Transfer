The Neo Files Transfer Platform employs a hybrid dependency management strategy, utilizing **npm** for the web client and **URL-based imports** for Supabase Edge Functions.

### Web Client (`web/`)
- **Package Manager**: Uses `npm` with `package-lock.json` (lockfileVersion 3) to ensure deterministic builds.
- **Core Dependencies**: 
  - `@supabase/supabase-js`: For backend integration.
  - `react`, `react-dom`, `react-router-dom`: For UI and routing.
  - `@tanstack/react-query`: For server-state management.
  - `tailwindcss`, `postcss`, `autoprefixer`: For styling.
- **Build Tool**: `vite` is used as the bundler and dev server, managed via `devDependencies`.
- **Convention**: Dependencies are declared in `package.json` with caret (`^`) versioning, allowing minor updates while locking major versions. The `node_modules` directory is present but typically ignored in version control via `.gitignore`.

### Supabase Edge Functions (`supabase/functions/`)
- **Management Approach**: Uses Deno's native URL-based imports. Dependencies are not declared in a manifest file like `deno.json` or `package.json` within the function directories.
- **Key Imports**:
  - `https://deno.land/std@0.168.0/http/server.ts`: Pinned to a specific standard library version.
  - `https://esm.sh/@supabase/supabase-js@2`: Uses the esm.sh CDN to import the Supabase client, pinned to major version 2.
- **Convention**: Dependencies are imported directly in the TypeScript files (`index.ts`). This approach leverages Deno's caching mechanism but requires manual updates to the URL strings to change versions. There is no central lockfile for these functions visible in the repository structure.