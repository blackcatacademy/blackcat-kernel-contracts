/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {BlackCatKernelAuthorityV1 as KernelAuthority} from "../src/KernelAuthority.sol";
import {FoundryVm} from "./FoundryVm.sol";

/// @notice Execute an arbitrary call via KernelAuthority (multi-device by design).
/// @dev This is a relayer helper: signatures are collected off-chain and passed in as an ABI-encoded `bytes[]`.
///
/// Env:
/// - `PRIVATE_KEY` (relayer / tx sender; pays gas)
/// - `BLACKCAT_KERNEL_AUTHORITY` (address)
/// - `BLACKCAT_TARGET` (address)
/// - `BLACKCAT_VALUE` (uint256; default 0)
/// - `BLACKCAT_CALLDATA` (bytes; hex-encoded calldata for the target function)
/// - `BLACKCAT_KERNEL_DEADLINE` (uint256; included in the signed digest)
/// - `BLACKCAT_KERNEL_SIGNATURES` (bytes; ABI-encoded `bytes[]` signatures, sorted by signer address)
contract KernelExecute {
    FoundryVm internal constant vm = FoundryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (bytes memory ret) {
        uint256 relayerPk = vm.envUint("PRIVATE_KEY");
        address payable authority = payable(vm.envAddress("BLACKCAT_KERNEL_AUTHORITY"));
        address target = vm.envAddress("BLACKCAT_TARGET");
        uint256 value = vm.envOr("BLACKCAT_VALUE", uint256(0));
        bytes memory data = vm.envBytes("BLACKCAT_CALLDATA");
        uint256 deadline = vm.envUint("BLACKCAT_KERNEL_DEADLINE");

        bytes memory sigBlob = vm.envBytes("BLACKCAT_KERNEL_SIGNATURES");
        bytes[] memory signatures = abi.decode(sigBlob, (bytes[]));

        vm.startBroadcast(relayerPk);
        ret = KernelAuthority(authority).execute(target, value, data, deadline, signatures);
        vm.stopBroadcast();
    }
}
