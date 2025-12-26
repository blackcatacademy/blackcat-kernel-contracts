/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {BlackCatAuditCommitmentHubV1 as AuditCommitmentHub} from "../src/AuditCommitmentHub.sol";
import {FoundryVm} from "./FoundryVm.sol";

/// @notice Deploy AuditCommitmentHub (optional append-only audit event stream).
/// @dev Env:
/// - `PRIVATE_KEY` (deployer)
contract DeployAuditCommitmentHub {
    FoundryVm internal constant vm = FoundryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (AuditCommitmentHub hub) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        hub = new AuditCommitmentHub();
        vm.stopBroadcast();
    }
}

