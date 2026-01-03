/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {BlackCatInstanceControllerV1 as InstanceController} from "../src/InstanceController.sol";
import {FoundryVm} from "./FoundryVm.sol";

/// @notice Create a per-install InstanceController using an existing implementation address.
/// @dev This avoids deploying a new (potentially size-limited) implementation on-chain.
///      The created instance is an EIP-1167 minimal proxy that delegates to the provided implementation.
///
/// IMPORTANT:
/// - This script initializes the instance with `releaseRegistry = address(0)` to disable ReleaseRegistry
///   enforcement for demo/testing instances (no global trust list required).
///
/// Env:
/// - `PRIVATE_KEY` (tx sender)
/// - `BLACKCAT_INSTANCE_CONTROLLER_IMPLEMENTATION` (address; existing implementation contract)
/// - `BLACKCAT_ROOT_AUTHORITY` (address; EOA/Safe/KernelAuthority)
/// - `BLACKCAT_UPGRADE_AUTHORITY` (address; EOA/Safe/KernelAuthority)
/// - `BLACKCAT_EMERGENCY_AUTHORITY` (address; EOA/Safe/KernelAuthority)
/// - `BLACKCAT_GENESIS_ROOT` (bytes32)
/// - `BLACKCAT_GENESIS_URI_HASH` (bytes32)
/// - `BLACKCAT_GENESIS_POLICY_HASH` (bytes32)
contract CreateInstanceNoRegistryFromImplementation {
    FoundryVm internal constant vm = FoundryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (address instance) {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");

        address implementation = vm.envAddress("BLACKCAT_INSTANCE_CONTROLLER_IMPLEMENTATION");
        require(implementation.code.length != 0, "CreateInstanceNoRegistry: impl not contract");

        address rootAuthority = vm.envAddress("BLACKCAT_ROOT_AUTHORITY");
        address upgradeAuthority = vm.envAddress("BLACKCAT_UPGRADE_AUTHORITY");
        address emergencyAuthority = vm.envAddress("BLACKCAT_EMERGENCY_AUTHORITY");

        bytes32 genesisRoot = vm.envBytes32("BLACKCAT_GENESIS_ROOT");
        bytes32 genesisUriHash = vm.envBytes32("BLACKCAT_GENESIS_URI_HASH");
        bytes32 genesisPolicyHash = vm.envBytes32("BLACKCAT_GENESIS_POLICY_HASH");

        vm.startBroadcast(deployerPk);
        instance = _clone(implementation);
        InstanceController(instance).initialize(
            rootAuthority,
            upgradeAuthority,
            emergencyAuthority,
            address(0),
            genesisRoot,
            genesisUriHash,
            genesisPolicyHash
        );
        vm.stopBroadcast();
    }

    function _clone(address impl) private returns (address instance) {
        // EIP-1167 minimal proxy initcode:
        // 0x3d602d80600a3d3981f3 | 0x363d3d373d3d3d363d73 | <impl> | 0x5af43d82803e903d91602b57fd5bf3
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, impl))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "CreateInstanceNoRegistry: clone failed");
    }
}

