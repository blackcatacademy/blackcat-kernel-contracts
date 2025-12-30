# BlackCat Kernel Contracts — Roadmap

This roadmap tracks the contract layer of the BlackCat “trust kernel” (Web3 / EVM).

## Current status (v1)

- ✅ Contracts + Foundry scripts implemented.
- ✅ CI gates: `forge fmt --check`, `forge test --via-ir`, EIP-170 size check, Slither (High/Medium=0).
- ✅ Edgen deployment + explorer verification (see reports in `docs/EDGEN_*_REPORT_*.md`).
- 🔜 External audit / formal review + ongoing hardening.

## Stage 0 — Specification (v1 complete; evolves over time)
- Threat model and invariants (what must never be possible).
  - See: [THREAT_MODEL](THREAT_MODEL.md)
  - Diagrams: [SECURITY_FLOWS](SECURITY_FLOWS.md)
- Audit checklist (pre-prod review notes).
  - See: [AUDIT_CHECKLIST](AUDIT_CHECKLIST.md)
- Canonical hashing rules for “release root” and “installed state root” (shared with `blackcat-integrity`).
- Contract interfaces and event schema:
  - `ReleaseRegistry` (official releases),
  - `InstanceController` (per-install trust authority),
  - `InstanceFactory` (setup ceremony + cloning).
- Trust modes and storage budgets:
  - `root+uri` baseline (cheap),
  - `full detail` mode (paranoid; chunked on-chain bytes or per-file hashes).
- Governance model:
  - authorities as external multisig wallets (Safe) rather than custom on-chain multisig logic,
  - separation of `root_authority` vs `upgrade_authority` vs `emergency_authority`.

## Stage 1 — Foundry scaffold + v1 contracts (complete)
- ✅ Foundry project scaffold (`foundry.toml`, fmt/test workflows).
- ✅ Implement skeletons with explicit events and minimal storage:
  - `ReleaseRegistry` mapping `componentId+version → root, uri, meta`,
  - `InstanceController` storing `active_root`, `active_uri`, `paused`, and upgrade slots,
  - `InstanceFactory` cloning controllers and emitting setup receipts.
- ✅ Optional `ManifestStore` for on-chain blob availability (paranoid “full detail” mode).
- ✅ Add revocation/trust model to `ReleaseRegistry` (`revoke`, `isTrustedRoot`).
- ✅ Add optional relayer ops to `ReleaseRegistry` + `ManifestStore` (EIP-712 / EIP-1271).
- ✅ Add optional `ReleaseRegistry` enforcement to `InstanceController` (genesis + upgrades).
- ✅ Add optional upgrade timelock (`minUpgradeDelaySec`) and reporter check-ins to `InstanceController`.
- ✅ Add 2-step authority rotation and incident reporting to `InstanceController`.
- ✅ Add deterministic instance creation via CREATE2 (`predictInstanceAddress`, `createInstanceDeterministic`).
- ✅ Unit tests for storage + access control + upgrade TTL/timelock behavior.
- ✅ Expand event assertions + fuzz tests (stateful/invariant-ish).

## Stage 2 — Setup ceremony (multi-device bootstrap) (complete)
- ✅ Replay protection via CREATE2 + salt (signatures cannot be replayed into multiple instances).
- ✅ EIP-712 typed “setup request” signatures (offline review + multi-device confirmation).
- ✅ Finalization flow:
  - ✅ binds the controller to chosen authorities,
  - ✅ pins the initial trust state (root/uriHash/policyHash),
  - ✅ emits an immutable genesis marker (`UpgradeActivated(previousRoot=0x0, ...)`).
- ✅ Optional authority mode `KernelAuthority` (EIP-712 threshold signer) for multi-device flows without Safe.

## Stage 3 — Upgrade state machine + emergency controls (complete)
- ✅ Upgrade flow: `propose → activate` with TTL and optional timelock.
- ✅ Emergency controls: `pause/unpause` (plus runtime-enforced “unsafe” decisions off-chain).
- ✅ Backward-compatible upgrades: optional compatibility overlap (rolling migrations).
- ✅ Break-glass rollback to compatibility state (direct + relayer signature option).
- ✅ Allow applying upgrades while paused (safer incident recovery).
- ✅ Permissionless guardrails: `pauseIfStale()` and `pauseIfActiveRootUntrusted()` for bot-driven auto-pause.
- ✅ Production hardening: `finalizeProduction(...)` helper to set + lock key knobs in one tx.
- ✅ Document canonical EIP-712 type strings for off-chain tooling (no on-chain `hash*` helpers to stay under EIP-170).
- ✅ Optional `AuditCommitmentHub` for batched audit Merkle roots (event hub, EIP-1271 reporter signatures).

## Stage 4 — Deployment + integration artifacts (v1 complete; packaging evolves)
- ✅ Deterministic addresses for instances (CREATE2).
- ✅ Deploy scripts for factories/registries + release ops (Foundry scripts).
- ✅ Publish ABI + artifacts to be consumed by:
  - `blackcat-core` runtime enforcement,
  - `blackcat-cli` / `blackcat-installer` operator flows.
  - (In this repo today: `out/` + `blackcat-cli.json`.)

## Stage 5 — Audit & hardening (current)
- External security audit + formal invariant review.
- Gas/cost benchmarks for trust modes.
- Upgrade safety: explicit “break glass” controls and post-incident recovery runbooks.
