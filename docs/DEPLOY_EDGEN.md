# Deploy to Edgen Chain (Chain ID `4207`)

Edgen Chain (EVM):
- RPC: `https://rpc.layeredge.io`
- Explorer: `https://edgenscan.io`
- Chain ID: `4207`

## Safety notes

- Use a **fresh test EOA** first. Do not reuse production keys.
- Never commit `.env` / private keys. This repo ignores `.env` via `.gitignore`.
- Run tests + size checks locally before broadcasting.

## 1) Generate an EOA (example)

Using Foundry’s `cast` (via Docker):

```bash
docker run --rm --entrypoint cast ghcr.io/foundry-rs/foundry:stable wallet new
```

Fund the printed address with enough `EDGEN` for gas.

## 2) Configure environment

Create a local `.env` file (not committed):

```bash
cat > .env <<'EOF'
# Deployer key used by Foundry scripts (hex is OK).
PRIVATE_KEY=0x...

# Owner of ReleaseRegistry (EOA/Safe/KernelAuthority).
BLACKCAT_RELEASE_REGISTRY_OWNER=0x...
EOF
```

## 3) Dry-run (no transactions sent)

Using Docker (recommended):

```bash
docker run --rm \
  --env-file .env \
  -v "$PWD":/app \
  -w /app \
  --entrypoint forge \
  ghcr.io/foundry-rs/foundry:stable \
  script script/DeployAll.s.sol:DeployAll --rpc-url edgen --chain-id 4207 -vvvv
```

## 4) Broadcast (sends transactions)

```bash
docker run --rm \
  --env-file .env \
  -v "$PWD":/app \
  -w /app \
  --entrypoint forge \
  ghcr.io/foundry-rs/foundry:stable \
  script script/DeployAll.s.sol:DeployAll --rpc-url edgen --chain-id 4207 --broadcast -vvvv
```

If the network doesn’t support EIP-1559 fees, retry with `--legacy`.

## Next steps

- Record deployed addresses in your runtime config (`blackcat-config`) and enforce strict production posture (fail-closed on trust uncertainty).
- Proceed with per-install instance creation via `InstanceFactory` scripts (deterministic CREATE2 recommended).
