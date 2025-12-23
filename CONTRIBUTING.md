# Contributing

## Workflow
- Keep changes focused and security-oriented (this repo is the trust kernel).
- Run formatting and tests locally:
  - `docker run --rm -v "$PWD":/app -w /app --entrypoint forge ghcr.io/foundry-rs/foundry:latest fmt`
  - `docker run --rm -v "$PWD":/app -w /app --entrypoint forge ghcr.io/foundry-rs/foundry:latest test`

## Commit style
- Conventional Commits (e.g. `feat:`, `fix:`, `docs:`, `chore:`).

## PR checklist
- `forge fmt` clean
- `forge test` green
- Spec/docs updated if you changed behavior (`docs/SPEC.md`, `docs/AUTHORITY_MODES.md`, `docs/ROADMAP.md`)

