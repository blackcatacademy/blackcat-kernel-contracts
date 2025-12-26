# Verify contracts on EdgenScan (Blockscout)

If the explorer shows methods as `0x12345678` (raw function selectors), it usually means:
- the contract is **not verified**, so the explorer does not know the ABI.

After verification, Blockscout can decode:
- function names + arguments,
- custom errors (if present),
- “Read/Write Contract” tabs.

EdgenScan is Blockscout and exposes an Etherscan-compatible API:
- Explorer: `https://edgenscan.io`
- API: `https://edgenscan.io/api`
- Foundry verification docs: https://docs.blockscout.com/devs/verification/foundry-verification

This repo uses Foundry, but the recommended way to run it is via Docker:
- `ghcr.io/foundry-rs/foundry:stable`

## What you must verify

Note on names:
- The Solidity contract names include a `BlackCat...V1` prefix/suffix for explorer clarity.
- This document still uses the short role names (`ReleaseRegistry`, `InstanceFactory`, `InstanceController`) when describing architecture.

When you deploy with `InstanceFactory`, it also deploys a single `InstanceController` **implementation**.
Per-install controllers are **EIP-1167 minimal proxy clones** that delegatecall into that implementation.

Verify at minimum:
1. `ReleaseRegistry`
2. `InstanceFactory`
3. `InstanceController` implementation (read from `InstanceFactory.implementation()`)

Optional (if deployed):
- `ManifestStore`
- `AuditCommitmentHub`
- `KernelAuthority`

## Get deployed addresses

Foundry writes broadcast logs under `broadcast/`.
Example paths (depending on script name):
- `broadcast/DeployAll.s.sol/4207/run-latest.json`

If you have the `InstanceFactory` address, you can fetch the implementation address:

```bash
docker run --rm --entrypoint cast ghcr.io/foundry-rs/foundry:stable \
  call <INSTANCE_FACTORY_ADDRESS> "implementation()(address)" --rpc-url https://rpc.layeredge.io
```

## Verify via Blockscout UI (most reliable)

1. Open the contract address on `https://edgenscan.io`.
2. Use **Verify & Publish**.
3. Choose **Solidity (Standard JSON Input)**.
4. Paste the Standard JSON input from Foundry.
   - Quick way: run `forge verify-contract --show-standard-json-input ...` (see below).
   - Alternatively, use Foundry build-info files under `out/build-info/<hash>.json`.

Important:
- The verification must match compiler settings (`0.8.24`, `via_ir`, optimizer runs).

## Verify via Foundry (CLI)

If your Foundry version supports the Blockscout verifier (it does in the Docker image):

Set an API key string (Blockscout often ignores it, but Foundry expects one):

```bash
export ETHERSCAN_API_KEY="blockscout"

OWNER_ADDRESS=0x...

CONSTRUCTOR_ARGS=$(docker run --rm --entrypoint cast ghcr.io/foundry-rs/foundry:stable \
  abi-encode "constructor(address)" "$OWNER_ADDRESS")

docker run --rm --entrypoint forge -v "$PWD":/work -w /work ghcr.io/foundry-rs/foundry:stable \
  verify-contract \
  --chain 4207 \
  --verifier blockscout \
  --verifier-url https://edgenscan.io/api \
  --watch \
  <CONTRACT_ADDRESS> \
  src/ReleaseRegistry.sol:BlackCatReleaseRegistryV1 \
  --constructor-args "$CONSTRUCTOR_ARGS"
```

To get the **Standard JSON Input** for manual UI verification:

```bash
docker run --rm --entrypoint forge -v "$PWD":/work -w /work ghcr.io/foundry-rs/foundry:stable \
  verify-contract \
  --show-standard-json-input \
  --chain 4207 \
  --verifier blockscout \
  --verifier-url https://edgenscan.io/api \
  <CONTRACT_ADDRESS> \
  src/ReleaseRegistry.sol:BlackCatReleaseRegistryV1
```

Repeat for other contracts (constructor args differ per contract).

If CLI verification fails, use the **UI method** above (it’s the quickest for Blockscout networks).

## Proxies / clones (method decoding on clones)

For EIP-1167 clones, Blockscout may still show `0x...` until it is told which implementation ABI to use.

Once the `InstanceController` implementation is verified:
- Open a clone address (the per-install controller),
- Use Blockscout’s proxy/implementation UI (if shown) to link it to the verified implementation.

After linking, function names should decode for calls sent to the clone.
