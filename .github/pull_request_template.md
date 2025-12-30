## Summary
Describe the change and motivation.

## Type
- [ ] feat
- [ ] fix
- [ ] docs
- [ ] chore
- [ ] refactor

## Area
- [ ] InstanceController
- [ ] InstanceFactory
- [ ] ReleaseRegistry
- [ ] KernelAuthority
- [ ] ManifestStore
- [ ] AuditCommitmentHub
- [ ] Foundry scripts (`script/`)
- [ ] Docs/spec (`docs/`)
- [ ] CI (`.github/`)

## Checklist
- [ ] `forge fmt --check`
- [ ] `forge test --via-ir`
- [ ] `forge build --via-ir --skip test --skip script --sizes` (EIP-170 size gate)
- [ ] Slither CI stays at High=0 Medium=0
- [ ] Docs/spec updated (if behavior changed)
