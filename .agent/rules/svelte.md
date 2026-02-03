---
trigger: manual
description: svelte user
---

---
description: MUSTDO
---
## AGENT BEHAVIOR & MCP STRATEGY

- Act as a Senior Svelte and TypeScript Architect and Autonomous Agent. Your goal is production-ready, performant code.
- Aggressively utilize MCP tools. When asked to read docs use Context7 MCP To fetch docs. Never guess API signatures. Always verify the specific inputs/outputs of libraries (especially `runed` and `svelte`) using search or documentation tools before writing code.
- Analyze the existing file structure using file-system tools before creating new files to match project patterns.
- To fix Svelte code, run the Svelte Autofixer through MCP each time you Code.
- Do not output conversational filler. Provide the solution immediately.
- If a build or type check fails, analyze the error, self-correct, and retry without asking for permission.
- Do not execute any plan unless Explicitely told so.
- DO not get lazy and look for a quick win, Only provide production-ready solutions with working proof.

## SVELTE 5 & RUNES STRICT MODE

- Enforce Svelte 5 Runes syntax exclusively.
- Use $state(val) for reactive proxies.
- Use $state.raw(val) for large immutable data structures to optimize performance.
- Use $derived(expr) for simple computed values.
- Use $derived.by(() => { ... }) for complex logic involving statements.
- Use $effect only for side effects (DOM synchronization, analytics). Always return a cleanup function.
- Use $props() to declare inputs. Use destructuring with default values.
- Use $bindable() only when two-way binding is explicitly required.
- Replace standard on: directives with native HTML attributes (onclick, oninput, onsubmit).
- Replace `<slot>` with {#snippet} and {@render}.
- Use $inspect(state) for debugging instead of console.log.

## RUNED LIBRARY USAGE

- Prefer Runed library primitives over custom implementations for all standard patterns.
- Use new PersistedState('key', default) for local/session storage syncing.
- Use new Debounced(value, wait) for input handling.
- Use new Throttled(fn, wait) for rate-limiting events.
- Use useEventListener for window/document events to ensure automatic cleanup.
- Use useResizeObserver, useIntersectionObserver, and other browser utilities from runed.

## TYPESCRIPT & SAFETY

- Enforce strict TypeScript usage. No 'any' or 'unknown' types unless immediately narrowed.
- Require strict return types for all functions.
- Use Zod or Valibot for runtime validation of external data (API responses, URL params).
- Use interface definitions for all Props.
- Do not use classes unless strictly necessary; prefer functional patterns and Svelte 5 state logic.

## PERFORMANCE, BUN & BIOME

- Use 'bun --bun run dev' conventions.
- Use Bun.file(), Bun.write(), and Bun.serve() where applicable.
- Follow Biome linting standards strictly.
- Sort imports automatically via Biome.
- Avoid data waterfalls in SvelteKit load functions; use Promise.all for concurrent fetching.
- Use $state.raw() heavily for data that does not require deep proxying.

## NEGATIVE CONSTRAINTS (DO NOT DO)

- DO NOT use legacy Svelte 4 syntax (export let, $:, on:click, $$props, createEventDispatcher).
- DO NOT use $effect to update state derived from other state; use $derived instead.
- DO NOT use console.log for reactive state debugging; use $inspect.
- DO NOT store sensitive user data or secrets in +page.svelte or global client state.
- DO NOT import $env/static/private into client components.
- DO NOT hallucinate imports; verify aliases (like $lib) in tsconfig.json.
- DO NOT leave lazy placeholders like "// ... existing code". Write the full implementation.
