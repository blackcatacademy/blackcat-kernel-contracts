/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {KernelAuthority} from "../src/KernelAuthority.sol";
import {FoundryVm} from "./FoundryVm.sol";

/// @notice Execute a batch of calls via KernelAuthority (single threshold approval).
/// @dev This is a relayer helper: signatures are collected off-chain and passed in as an ABI-encoded `bytes[]`.
///
/// Env:
/// - `PRIVATE_KEY` (relayer / tx sender; pays gas)
/// - `BLACKCAT_KERNEL_AUTHORITY` (address)
/// - `BLACKCAT_KERNEL_DEADLINE` (uint256; included in the signed digest)
/// - `BLACKCAT_KERNEL_SIGNATURES` (bytes; ABI-encoded `bytes[]` signatures, sorted by signer address)
/// - `BLACKCAT_KERNEL_BATCH_TARGETS` (bytes; ABI-encoded `address[]`)
/// - `BLACKCAT_KERNEL_BATCH_VALUES` (bytes; ABI-encoded `uint256[]`)
/// - `BLACKCAT_KERNEL_BATCH_CALLDATA` (bytes; ABI-encoded `bytes[]`)
contract KernelExecuteBatch {
    FoundryVm internal constant vm = FoundryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        uint256 relayerPk = vm.envUint("PRIVATE_KEY");
        address payable authority = payable(vm.envAddress("BLACKCAT_KERNEL_AUTHORITY"));
        uint256 deadline = vm.envUint("BLACKCAT_KERNEL_DEADLINE");

        bytes memory sigBlob = vm.envBytes("BLACKCAT_KERNEL_SIGNATURES");
        bytes[] memory signatures = abi.decode(sigBlob, (bytes[]));

        address[] memory targets = abi.decode(vm.envBytes("BLACKCAT_KERNEL_BATCH_TARGETS"), (address[]));
        uint256[] memory values = abi.decode(vm.envBytes("BLACKCAT_KERNEL_BATCH_VALUES"), (uint256[]));
        bytes[] memory data = abi.decode(vm.envBytes("BLACKCAT_KERNEL_BATCH_CALLDATA"), (bytes[]));

        vm.startBroadcast(relayerPk);
        KernelAuthority(authority).executeBatch(targets, values, data, deadline, signatures);
        vm.stopBroadcast();
    }
}
