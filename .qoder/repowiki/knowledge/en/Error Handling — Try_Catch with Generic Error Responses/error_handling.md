## Overview

The Neo Files Transfer Platform uses a simple, informal error handling approach centered on **try/catch blocks** that convert all errors into generic HTTP responses or console logs. There is no centralized error type system, no custom error classes, and no structured error codes.

---

## Backend (Supabase Edge Functions)

### Pattern: Uniform Try/Catch Wrapper

All seven Edge Functions (`upload-file`, `download-file`, `generate-share-link`, `validate-folder`, `delete-file`, `rename-file`, `upload-version`) follow the same pattern:

```typescript
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // ... business logic with validation throws
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    )
  }
})
```

### Key Characteristics

1. **Validation via thrown Errors**: Input validation and auth checks throw plain `Error` objects with descriptive messages (e.g., `throw new Error("Missing authorization header")`, `throw new Error("Not authenticated")`).

2. **Single catch-all handler**: Every function has one `catch` block at the end that returns `{ error: error.message }` with HTTP status `400`. This means **all errors—validation failures, auth errors, external API failures—are mapped to 400**, losing semantic distinction between client errors (4xx) and server errors (5xx).

3. **Exception: download-file**: The `download-file` function deviates by returning specific HTML error pages with correct HTTP status codes (404 for not found, 403 for access denied, 503 for service disabled, 500 for unexpected errors). It also uses `console.error()` for logging instead of exposing error details to the client.

4. **External API error extraction**: When calling Google Drive APIs, functions extract error messages from the response body (`errorData.error?.message`) and re-throw them as plain `Error` objects.

5. **No error logging middleware**: There is no centralized logging. Some functions use `console.error()` (e.g., `delete-file`), others do not log at all.

---

## Frontend (React Web Client)

### Pattern: Ad-hoc Error Handling

1. **AuthContext**: Uses a single `try/catch` around profile loading with `console.error('Error loading profile:', err)`. The `signInWithGoogle` function propagates errors upward via `throw error`.

2. **Route Guards**: `ProtectedRoute` and `AdminRoute` in `App.jsx` handle missing authentication by redirecting to login/admin pages rather than displaying errors.

3. **Error Pages**: Dedicated static pages exist for common HTTP errors:
   - `AccessDeniedPage.jsx` — displays 403 with icon and navigation link
   - `FileNotFoundPage.jsx` — displays 404 with icon and navigation link
   - These are rendered via React Router's `*` catch-all route but are **not dynamically triggered** by API errors; they only handle unmatched routes.

4. **Toast Notifications**: `AuthCallback.jsx` uses `react-hot-toast` to display user-facing error messages (e.g., account not approved). This is the only instance of user-facing error feedback in the examined code.

5. **No global error boundary**: There is no React Error Boundary component to catch rendering errors.

6. **No API error abstraction**: The `supabase.js` service file exports only a raw Supabase client with no wrapper for error handling. Components must handle Supabase errors inline.

---

## Conventions Developers Should Follow

1. **Edge Functions**: Always wrap handler logic in `try/catch`. Throw `new Error("descriptive message")` for validation/auth failures. Return `{ error: error.message }` with status 400 in the catch block.

2. **HTTP Status Codes**: Be aware that the current pattern maps all caught errors to 400. If semantic status codes matter, handle them explicitly before the catch block (as `download-file` does).

3. **Frontend Errors**: Use `console.error()` for debugging. Use `react-hot-toast` for user-facing notifications. Handle Supabase query errors inline since there is no centralized error handler.

4. **No Custom Error Types**: Do not introduce custom error classes unless the team agrees to refactor the entire codebase. The current convention relies on string messages.

5. **Security**: Never expose internal error details to clients. The `download-file` function correctly hides technical details behind generic HTML pages; other functions expose `error.message` which may leak implementation details.

---

## Summary

| Aspect | Approach |
|---|---|
| Error types | Plain `Error` objects only |
| Propagation | Throw in try block, catch at function boundary |
| HTTP mapping | Mostly 400 for all errors; `download-file` uses 403/404/500/503 |
| Logging | `console.error()` sporadically; no structured logging |
| Frontend feedback | `react-hot-toast` for toasts; static error pages for route mismatches |
| Centralization | None — each function/component handles errors independently |
