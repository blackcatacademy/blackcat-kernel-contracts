# Edgen Chain Smoke Report (2025-12-26)

Chain:
- RPC: `https://rpc.layeredge.io`
- Explorer: `https://edgenscan.io`
- `chain_id`: `4207`

Deployer EOA (dry-run):
- `0x479f63C62dA5271Fa88A3d20b9AcE926E89de678`

## Deployed contracts

Global:
- `BlackCatReleaseRegistryV1`: `0x22681Ee2153B7B25bA6772B44c160BB60f4C333E`
- `BlackCatInstanceFactoryV1`: `0x92C80Cff5d75dcD3846EFb5DF35957D5Aed1c7C5`
- `BlackCatInstanceControllerV1` implementation (deployed by factory): `0x7246Ed88F19a8429eDb41c5700C0C52C2548C3fE`
- `BlackCatKernelAuthorityV1`: `0xC8EA2E0eEBA67512D6a4B46dB8Ee398e68efcC84`
- `BlackCatManifestStoreV1`: `0x76D82850b7ff01E1fFb584Aa7B5fD84dF38bA89F`
- `BlackCatAuditCommitmentHubV1`: `0x4e4425be104D629ae7fda45Bc4E36F19A8a960B6`

Per-install:
- `InstanceController` clone (EIP-1167): `0xae32F6d7BF7C155Cd099BD0Cc0F80048A0275137`

## What was exercised on-chain

ReleaseRegistry:
- Published `componentId=keccak256("blackcat-core")`:
  - v1 root (genesis), then revoked it.
  - v2 root (upgrade), kept it trusted.

InstanceFactory + InstanceController:
- Created a per-install controller clone via `createInstance(...)` using the trusted genesis root.
- Ran `finalizeProduction(...)` with a fast test config:
  - `minUpgradeDelaySec = 5`
  - `maxCheckInAgeSec = 10`
  - `autoPauseOnBadCheckIn = true`
  - `compatibilityWindowSec = 0`
  - `emergencyCanUnpause = false`
- Set reporter authority (2-step transfer) and performed:
  - good check-in (ok=true),
  - bad check-in (ok=false → incident + auto-pause),
  - `pauseIfStale()` (after delay) → incident + pause,
  - `pauseIfActiveRootUntrusted()` after revoking the active root → incident + pause,
  - `unpause()` (root-only in this config).
- Proposed and activated an upgrade via registry v2 after the min delay.
- Posted and locked an attestation key (`setAttestationAndLock`).

KernelAuthority:
- Deployed with 3 signers (threshold 2).
- Executed a self-call via `execute(...)` (signed by 2 signers) to `setConfig(...)` to the same config (sanity).

ManifestStore:
- Uploaded a tiny test blob (`sha256`-based `blobHash`) using `appendChunks(...)` + `finalize(...)`.

AuditCommitmentHub:
- Posted one audit commitment via `commit(...)` (direct reporter path), which internally resolved `reporterAuthority()` from the instance controller.

## Notes

- Raw Foundry broadcast logs (tx hashes, receipts) were written under `broadcast/**/4207/run-latest.json` (gitignored).
- Verification plan: see `docs/VERIFY_EDGENSCAN.md`.

