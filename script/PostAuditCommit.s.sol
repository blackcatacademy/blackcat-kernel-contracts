/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {BlackCatAuditCommitmentHubV1 as AuditCommitmentHub} from "../src/AuditCommitmentHub.sol";
import {FoundryVm} from "./FoundryVm.sol";

/// @notice Post an audit commitment (direct reporter path).
/// @dev Must be executed by `InstanceController.reporterAuthority()`.
///
/// Env:
/// - `PRIVATE_KEY`
/// - `BLACKCAT_AUDIT_COMMITMENT_HUB`
/// - `BLACKCAT_INSTANCE_CONTROLLER`
/// - `BLACKCAT_AUDIT_SEQ_FROM` (uint)
/// - `BLACKCAT_AUDIT_SEQ_TO` (uint)
/// - `BLACKCAT_AUDIT_MERKLE_ROOT` (bytes32)
/// - `BLACKCAT_AUDIT_META_HASH` (bytes32; optional, default 0x0)
contract PostAuditCommit {
    FoundryVm internal constant vm = FoundryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address hub = vm.envAddress("BLACKCAT_AUDIT_COMMITMENT_HUB");
        address instance = vm.envAddress("BLACKCAT_INSTANCE_CONTROLLER");

        uint64 seqFrom = uint64(vm.envUint("BLACKCAT_AUDIT_SEQ_FROM"));
        uint64 seqTo = uint64(vm.envUint("BLACKCAT_AUDIT_SEQ_TO"));
        bytes32 root = vm.envBytes32("BLACKCAT_AUDIT_MERKLE_ROOT");
        bytes32 meta = vm.envOr("BLACKCAT_AUDIT_META_HASH", bytes32(0));

        vm.startBroadcast(pk);
        AuditCommitmentHub(hub).commit(instance, seqFrom, seqTo, root, meta);
        vm.stopBroadcast();
    }
}

