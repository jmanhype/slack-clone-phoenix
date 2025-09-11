# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: Elixir source. Contexts under `lib/slack_clone/` (e.g., Accounts, Workspaces, Channels, Messages). Web layer under `lib/slack_clone_web/` (controllers, LiveViews, components).
- `assets/`: Frontend assets built with esbuild + Tailwind.
- `test/`: ExUnit tests (`*_test.exs`), helpers in `test/support/`; includes integration, performance, and security suites.
- `priv/`: static files and `repo` (migrations, seeds).
- `mobile/`: React Native client for iOS/Android (see `mobile/README.md`).

## Build, Test, and Development Commands
- `mix setup`: Install deps, setup DB, build assets.
- `mix phx.server` or `iex -S mix phx.server`: Run the app (dev at http://localhost:4000).
- `mix test`: Create/migrate test DB and run tests (alias configured).
- `mix credo --strict`: Lint for style and consistency.
- `mix dialyzer`: Static analysis (specs/types).
- `mix assets.build` / `mix assets.deploy`: Build/minify assets; deploy also runs `phx.digest`.
- Useful scripts: `mix run scripts/auth.exs` (JWT helper), `mix run scripts/demo.exs` (feature demo).

## Coding Style & Naming Conventions
- Format with `mix format` (see `.formatter.exs`). Elixir: 2‑space indent, snake_case functions/files, PascalCase modules.
- Prefer typespecs (`@spec`) and docs (`@doc`) for public APIs.
- Phoenix: keep business logic in contexts; LiveView/components under `slack_clone_web`.
- Run `mix credo --strict` before committing.

## Testing Guidelines
- Framework: ExUnit; factories via ExMachina; Faker for data.
- Naming: mirror source paths; tests end with `_test.exs`.
- Coverage: `MIX_ENV=test mix coveralls.html` (uses excoveralls; opens HTML report).
- Database: tests use SQL Sandbox; avoid global state.

## Commit & Pull Request Guidelines
- Commits: clear, imperative subject; group related changes. Recommended style: Conventional Commits (`feat:`, `fix:`, `chore:`) for clarity.
- PRs: include summary, rationale, screenshots for UI, and migration notes. Link issues. Ensure CI basics pass locally: `mix test`, `mix credo --strict`, `mix dialyzer`, `mix format`.

## Security & Configuration Tips
- Configure env in `config/*` and `runtime.exs`; never commit secrets. Use `.env` locally.
- DB defaults are in `config/dev.exs` and `config/test.exs`. Seed via `mix run priv/repo/seeds.exs`.
- For HTTPS in dev: `mix phx.gen.cert` and update endpoint config.
