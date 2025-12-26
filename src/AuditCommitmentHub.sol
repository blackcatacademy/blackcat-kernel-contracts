/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

/// @notice Optional event hub for committing off-chain audit Merkle roots on-chain in a batched/cost-aware way.
/// @dev This contract does not attempt to “enforce” server behavior. It provides:
/// - an append-only, queryable event stream (commit history),
/// - monotonic per-instance sequence enforcement (`lastSeq`),
/// - direct reporter commits and relayed (EIP-712) commits with EIP-1271 support.
///
/// Intended integration:
/// - the runtime maintains an append-only audit log and periodically commits a Merkle root,
/// - reporter authority is stored in `InstanceController.reporterAuthority`,
/// - in production, the runtime should fail closed even without this hub; this is an additional integrity/audit signal.
contract AuditCommitmentHub {
    bytes4 private constant EIP1271_MAGICVALUE = 0x1626ba7e;
    uint256 private constant SECP256K1N_HALF = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    uint256 private constant EIP2098_S_MASK = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("BlackCatAuditCommitmentHub");
    bytes32 private constant VERSION_HASH = keccak256("1");

    bytes32 private constant COMMIT_TYPEHASH = keccak256(
        "Commit(address instance,uint64 seqFrom,uint64 seqTo,bytes32 merkleRoot,bytes32 metaHash,uint256 deadline)"
    );

    /// @notice Per-instance committed range cursor (monotonic).
    mapping(address => uint64) public lastSeq;

    event SignatureConsumed(address indexed signer, bytes32 indexed digest, address indexed executor);
    event CommitmentPosted(
        address indexed instance,
        address indexed reporter,
        uint64 seqFrom,
        uint64 seqTo,
        bytes32 merkleRoot,
        bytes32 metaHash,
        address indexed relayer
    );

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }

    /// @notice Compute the EIP-712 digest that must be signed by the reporter authority for `commitAuthorized`.
    function hashCommit(
        address instance,
        uint64 seqFrom,
        uint64 seqTo,
        bytes32 merkleRoot,
        bytes32 metaHash,
        uint256 deadline
    ) external view returns (bytes32) {
        require(instance != address(0), "AuditCommitmentHub: instance=0");
        require(seqFrom != 0, "AuditCommitmentHub: seqFrom=0");
        require(seqTo >= seqFrom, "AuditCommitmentHub: bad seq range");
        require(merkleRoot != bytes32(0), "AuditCommitmentHub: root=0");
        return _hashCommit(instance, seqFrom, seqTo, merkleRoot, metaHash, deadline);
    }

    /// @notice Direct commit path (no signature) for reporter authority addresses that can submit transactions.
    function commit(address instance, uint64 seqFrom, uint64 seqTo, bytes32 merkleRoot, bytes32 metaHash) external {
        address reporter = _getReporterAuthority(instance);
        require(msg.sender == reporter, "AuditCommitmentHub: not reporter");
        _commit(instance, reporter, seqFrom, seqTo, merkleRoot, metaHash, msg.sender);
    }

    /// @notice Relayed commit path (EIP-712) to allow air-gapped/multi-device signers to approve without paying gas.
    function commitAuthorized(
        address instance,
        uint64 seqFrom,
        uint64 seqTo,
        bytes32 merkleRoot,
        bytes32 metaHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "AuditCommitmentHub: expired");

        address reporter = _getReporterAuthority(instance);
        bytes32 digest = _hashCommit(instance, seqFrom, seqTo, merkleRoot, metaHash, deadline);

        require(_isValidSignatureNow(reporter, digest, signature), "AuditCommitmentHub: invalid reporter signature");
        emit SignatureConsumed(reporter, digest, msg.sender);

        _commit(instance, reporter, seqFrom, seqTo, merkleRoot, metaHash, msg.sender);
    }

    function _commit(
        address instance,
        address reporter,
        uint64 seqFrom,
        uint64 seqTo,
        bytes32 merkleRoot,
        bytes32 metaHash,
        address relayer
    ) private {
        require(instance != address(0), "AuditCommitmentHub: instance=0");
        require(seqFrom != 0, "AuditCommitmentHub: seqFrom=0");
        require(seqTo >= seqFrom, "AuditCommitmentHub: bad seq range");
        require(merkleRoot != bytes32(0), "AuditCommitmentHub: root=0");

        uint64 expectedFrom = lastSeq[instance] + 1;
        require(seqFrom == expectedFrom, "AuditCommitmentHub: seq mismatch");

        lastSeq[instance] = seqTo;
        emit CommitmentPosted(instance, reporter, seqFrom, seqTo, merkleRoot, metaHash, relayer);
    }

    function _hashCommit(
        address instance,
        uint64 seqFrom,
        uint64 seqTo,
        bytes32 merkleRoot,
        bytes32 metaHash,
        uint256 deadline
    ) private view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(COMMIT_TYPEHASH, instance, seqFrom, seqTo, merkleRoot, metaHash, deadline)
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    function _getReporterAuthority(address instance) private view returns (address reporter) {
        require(instance.code.length != 0, "AuditCommitmentHub: instance not contract");

        (bool ok, bytes memory ret) = instance.staticcall(abi.encodeWithSignature("reporterAuthority()"));
        require(ok && ret.length >= 32, "AuditCommitmentHub: bad instance");

        reporter = abi.decode(ret, (address));
        require(reporter != address(0), "AuditCommitmentHub: reporter not set");
    }

    function _isValidSignatureNow(address signer, bytes32 digest, bytes memory signature) private view returns (bool) {
        if (signer.code.length == 0) {
            return _recover(digest, signature) == signer;
        }

        (bool ok, bytes memory ret) =
            signer.staticcall(abi.encodeWithSignature("isValidSignature(bytes32,bytes)", digest, signature));
        // Casting to `bytes4` is safe because we check `ret.length >= 4` first.
        // forge-lint: disable-next-line(unsafe-typecast)
        return ok && ret.length >= 4 && bytes4(ret) == EIP1271_MAGICVALUE;
    }

    function _recover(bytes32 digest, bytes memory signature) private pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (signature.length == 65) {
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }

            if (v < 27) {
                v += 27;
            }
        } else if (signature.length == 64) {
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }

            s = bytes32(uint256(vs) & EIP2098_S_MASK);
            v = uint8((uint256(vs) >> 255) + 27);
        } else {
            revert("AuditCommitmentHub: bad signature length");
        }

        require(v == 27 || v == 28, "AuditCommitmentHub: bad v");
        require(uint256(s) <= SECP256K1N_HALF, "AuditCommitmentHub: bad s");

        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0), "AuditCommitmentHub: bad signature");
        return recovered;
    }
}

