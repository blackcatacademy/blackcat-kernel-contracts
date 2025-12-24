# Threat Model (Draft)

This document describes the **threat model** for the BlackCat Trust Kernel.

Important:
- These contracts are **not audited**.
- The Trust Kernel is a *system*: on-chain contracts + off-chain runtime enforcement (`blackcat-core`) + secure config handling (`blackcat-config`).

Related:
- Flows/diagrams: `blackcat-kernel-contracts/docs/SECURITY_FLOWS.md`
- Spec: `blackcat-kernel-contracts/docs/SPEC.md`
- Audit checklist: `blackcat-kernel-contracts/docs/AUDIT_CHECKLIST.md`

## Trust boundaries (high level)

Assumption: the server filesystem is **not** a trust anchor (FTP mistakes, compromised credentials, partial upgrades).

```mermaid
flowchart TB
  subgraph Untrusted["Untrusted / easily compromised"]
    FS["Server filesystem\n(app code, configs)"]
    Host["Hosting / OS\n(admins, processes)"]
    Net["Local network path\n(DNS/proxy/MITM risk)"]
    Relayer["Relayer infra\n(submitter, pays gas)"]
  end

  subgraph TrustAnchors["Trust anchors (must be protected)"]
    Keys["Authority keys\n(Safe / Ledger / KernelAuthority signers)"]
    Chain["EVM chain state\n(InstanceController, ReleaseRegistry)"]
  end

  subgraph Verifiers["Verifiers (must fail closed in prod)"]
    Runtime["blackcat-core runtime\n(quorum reads, policy)"]
    Config["blackcat-config\n(file perms, canonical config)"]
  end

  Keys --> Chain
  FS --> Runtime
  Config --> Runtime
  Runtime --> Chain
  Net --> Runtime
  Relayer --> Chain
```

Core principle:
- **On-chain state** is the source of truth for install/upgrade integrity and emergency controls.
- **Off-chain runtime** must refuse unsafe operations if it cannot verify on-chain state (production = fail closed).

## Assets to protect

1. Authority custody (root/upgrade/emergency/reporter):
   - signer sets, thresholds, rotation process, and recovery process.
2. On-chain install identity:
   - the correct `InstanceController` address for the installation.
3. Integrity anchors:
   - `activeRoot`, `activeUriHash`, `activePolicyHash`, compatibility roots (if enabled).
4. Runtime config (security-critical):
   - `chain_id`, RPC quorum, contract addresses, fail-closed mode, and outbox/buffer behavior.
5. Release trust:
   - official roots in `ReleaseRegistry` and revocations.

## Threat actors (examples)

- Remote attacker with **write access** to the server filesystem (FTP, compromised app user, vulnerable plugin).
- Malicious or compromised **hosting operator** / admin.
- Attacker controlling **one RPC endpoint** (or capable of returning inconsistent/stale data).
- Attacker with access to **relayer** (can submit transactions but must not be able to forge signatures).
- Supply-chain attacker trying to inject modified artifacts at install/upgrade time.
- Key compromise (one device stolen, malware, leaked seed phrase).

## Security goals

1. **Tamper-evident by default**: filesystem modifications become detectable.
2. **Tamper-resistance when hardened**: unsafe writes are blocked in production without valid on-chain authorization.
3. **Multi-device by design**: root/upgrade/emergency actions require multiple devices (Safe or KernelAuthority).
4. **Replay resistance**: signatures cannot be reused across chains/contracts/time or after nonce increments.
5. **Clear emergency behavior**: incident → pause → recover, with explicit audit trail.

## Key threats and mitigations (selected)

| Threat | What happens | Primary mitigation |
|---|---|---|
| Filesystem tamper (code/config) | attacker modifies files or redirects config | runtime verifies on-chain state + pinned config hash via attestations + fail closed |
| “Redirect runtime” attack | attacker changes chain/RPC/controller address | file permission checks + on-chain pinned config hash + locking |
| Malicious release injection | attacker tries to upgrade to untrusted root | `ReleaseRegistry.isTrustedRoot` checks (if enabled) + revocation |
| Relayer compromise | attacker can submit tx but not sign | relayer paths require valid EIP-712 signature (EOA/EIP-1271) |
| Signature replay | reuse a signature on another chain/contract/time | EIP-712 domain separator + nonce + deadline |
| RPC lies / stale reads | runtime sees inconsistent state | multi-RPC quorum + max-stale + fail closed |
| Chain / RPC outage | cannot read chain state reliably | buffer/outbox + deny security-critical writes + incident escalation thresholds |
| Single key compromise | attacker gets one key | Safe/KernelAuthority threshold; keep emergency keys offline |

## Attack narrative: filesystem tamper → detection → auto-pause

```mermaid
sequenceDiagram
  autonumber
  participant Attacker as Attacker
  participant FS as Server filesystem
  participant Runtime as blackcat-core runtime
  participant IC as InstanceController

  Attacker->>FS: Modify files or config
  Runtime->>FS: Read files/config
  Runtime->>Runtime: Compute observedRoot/uriHash/policyHash
  Runtime->>IC: eth_call snapshotV2() (quorum)
  IC-->>Runtime: activeRoot/uriHash/policyHash + flags
  alt mismatch detected
    Runtime->>Runtime: Deny writes (fail closed)
    Runtime->>IC: (optional) checkIn/reportIncident (if authorized)
    IC-->>Runtime: IncidentReported + Paused (if enabled)
  else match
    Runtime->>Runtime: Continue normal operations
  end
```

Expected:
- A compromised filesystem cannot silently change the “accepted” integrity state.
- Production systems deny unsafe writes when observed state does not match on-chain state.

Forbidden:
- “Accepting” a mismatch because a single RPC endpoint responded.
- Overriding trust checks via environment variables in production.

## Attack narrative: RPC compromise (why quorum matters)

```mermaid
flowchart TB
  Start["Runtime wants state"] --> Q["Query RPC endpoints (in parallel)"]
  Q --> R1["RPC #1 response"]
  Q --> R2["RPC #2 response"]
  Q --> R3["RPC #3 response"]

  R1 --> Compare["Compare responses\n(block number, state bytes,\nreturn data hashes)"]
  R2 --> Compare
  R3 --> Compare

  Compare -->|"Quorum agrees + not stale"| OK["Proceed\n(allow reads; allow writes only if checks pass)"]
  Compare -->|"No quorum OR stale beyond max_stale_sec"| Fail["Fail closed\n(deny security-critical writes)"]
```

Expected:
- Production uses quorum (recommended `2/3`, minimum `2/2`).
- If quorum is lost, the system continues **read-only** (up to `max_stale_sec`) and denies writes.

Forbidden:
- Trusting a single RPC response for security-critical state.

## Attack narrative: relayer compromise (why signatures matter)

```mermaid
flowchart LR
  Relayer["Relayer compromised"] -->|"can send tx"| Chain["EVM chain"]

  Chain -->|"requires signature"| Gate["Authorized function\n...Authorized(..., signature)"]

  Gate -->|"invalid signature"| Revert["REVERT"]
  Gate -->|"valid signature"| Effect["State change\n+ SignatureConsumed event"]
```

Expected:
- Relayer compromise does not grant authority; it only affects availability and transaction ordering.
- Authorities must be signers, never relayers.

## Non-goals (v1)

- Protecting against a full EVM consensus failure / chain rewrite.
- Protecting against “perfect” endpoint capture where an attacker controls *all* RPC endpoints used by the runtime.
- Preventing misuse by an authorized root authority (root authority is ultimately trusted).

## Security posture: dev vs production

- Development:
  - can run in warn/continue mode to ease iteration,
  - still records incidents and mismatches for visibility.
- Production:
  - fail closed on trust uncertainty,
  - strict runtime config permissions,
  - pin and lock runtime config hashes on-chain,
  - multi-device authorities only (Safe or KernelAuthority).

