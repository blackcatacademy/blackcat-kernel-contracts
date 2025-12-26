# EdgenScan verification report (2025-12-26)

Network:
- Chain: Edgen Chain
- Chain ID: `4207`
- RPC: `https://rpc.layeredge.io`
- Explorer: `https://edgenscan.io`
- API: `https://edgenscan.io/api` (Blockscout)

Verifier tooling:
- Foundry Docker image: `ghcr.io/foundry-rs/foundry:stable`
- API key env used: `ETHERSCAN_API_KEY=blockscout` (Blockscout-compatible/Etherscan-style API)

Deployer EOA:
- `0x479f63C62dA5271Fa88A3d20b9AcE926E89de678`

## Verified contracts

### `BlackCatReleaseRegistryV1`
- Address: `0x22681Ee2153B7B25bA6772B44c160BB60f4C333E`
- Source: `src/ReleaseRegistry.sol:BlackCatReleaseRegistryV1`
- Constructor: `constructor(address initialOwner)` with `initialOwner = 0x479f63C62dA5271Fa88A3d20b9AcE926E89de678`
- Verification GUID: `22681ee2153b7b25ba6772b44c160bb60f4c333e694f02d3`
- Explorer: `https://edgenscan.io/address/0x22681ee2153b7b25ba6772b44c160bb60f4c333e`

### `BlackCatInstanceFactoryV1`
- Address: `0x92C80Cff5d75dcD3846EFb5DF35957D5Aed1c7C5`
- Source: `src/InstanceFactory.sol:BlackCatInstanceFactoryV1`
- Constructor: `constructor(address releaseRegistry_)` with `releaseRegistry_ = 0x22681Ee2153B7B25bA6772B44c160BB60f4C333E`
- Verification GUID: `92c80cff5d75dcd3846efb5df35957d5aed1c7c5694f036f`
- Explorer: `https://edgenscan.io/address/0x92c80cff5d75dcd3846efb5df35957d5aed1c7c5`

### `BlackCatInstanceControllerV1` (implementation)
- Address: `0x7246Ed88F19a8429eDb41c5700C0C52C2548C3fE`
- Source: `src/InstanceController.sol:BlackCatInstanceControllerV1`
- Constructor: none (initializer-based)
- Verification GUID: `7246ed88f19a8429edb41c5700c0c52c2548c3fe694f034c`
- Explorer: `https://edgenscan.io/address/0x7246ed88f19a8429edb41c5700c0c52c2548c3fe`

### `BlackCatKernelAuthorityV1`
- Address: `0xC8EA2E0eEBA67512D6a4B46dB8Ee398e68efcC84`
- Source: `src/KernelAuthority.sol:BlackCatKernelAuthorityV1`
- Constructor: `constructor(address[] signers_, uint256 threshold_)`
  - `signers_` (ascending):
    - `0x06307a2459E82C39d6195E4CE483e7A4cc429e3D`
    - `0x530Bb9B1462f4F0758F3e4E455473F02740F3fAf`
    - `0xaf4D8056122194920B6769400Eff93a445DD22bB`
  - `threshold_ = 2`
- Verification GUID: `c8ea2e0eeba67512d6a4b46db8ee398e68efcc84694f0331`
- Explorer: `https://edgenscan.io/address/0xc8ea2e0eeba67512d6a4b46db8ee398e68efcc84`

### `BlackCatManifestStoreV1`
- Address: `0x76D82850b7ff01E1fFb584Aa7B5fD84dF38bA89F`
- Source: `src/ManifestStore.sol:BlackCatManifestStoreV1`
- Constructor: `constructor(address initialOwner)` with `initialOwner = 0x479f63C62dA5271Fa88A3d20b9AcE926E89de678`
- Verification GUID: `76d82850b7ff01e1ffb584aa7b5fd84df38ba89f694f02ee`
- Explorer: `https://edgenscan.io/address/0x76d82850b7ff01e1ffb584aa7b5fd84df38ba89f`

### `BlackCatAuditCommitmentHubV1`
- Address: `0x4e4425be104D629ae7fda45Bc4E36F19A8a960B6`
- Source: `src/AuditCommitmentHub.sol:BlackCatAuditCommitmentHubV1`
- Constructor: none
- Verification GUID: `4e4425be104d629ae7fda45bc4e36f19a8a960b6694f0308`
- Explorer: `https://edgenscan.io/address/0x4e4425be104d629ae7fda45bc4e36f19a8a960b6`

## Note: EIP-1167 clones (per-install controllers)

The per-install controller created by `BlackCatInstanceFactoryV1` is an EIP-1167 minimal proxy clone and may still show `0x...` selectors until the explorer links it to the verified implementation ABI.

Example clone from the smoke run:
- Clone: `0xae32F6d7BF7C155Cd099BD0Cc0F80048A0275137`
- Implementation: `0x7246Ed88F19a8429eDb41c5700C0C52C2548C3fE`

If EdgenScan shows a proxy UI:
- open the clone address,
- set/link the implementation to the verified `BlackCatInstanceControllerV1` implementation.

