/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {InstanceController} from "../src/InstanceController.sol";
import {InstanceFactory} from "../src/InstanceFactory.sol";
import {KernelAuthority} from "../src/KernelAuthority.sol";
import {ReleaseRegistry} from "../src/ReleaseRegistry.sol";

contract KernelAuthorityIntegrationTest is TestBase {
    struct Signer {
        address addr;
        uint256 pk;
    }

    Signer private s0;
    Signer private s1;
    Signer private s2;

    KernelAuthority private authority;
    ReleaseRegistry private registry;
    InstanceFactory private factory;

    bytes32 private constant COMPONENT_ID = keccak256("blackcat-core");

    function setUp() public {
        Signer memory a = Signer({pk: 0xA11CE, addr: vm.addr(0xA11CE)});
        Signer memory b = Signer({pk: 0xB0B, addr: vm.addr(0xB0B)});
        Signer memory c = Signer({pk: 0xC0DE, addr: vm.addr(0xC0DE)});

        Signer[3] memory sorted = _sort3(a, b, c);
        s0 = sorted[0];
        s1 = sorted[1];
        s2 = sorted[2];

        address[] memory signers = new address[](3);
        signers[0] = s0.addr;
        signers[1] = s1.addr;
        signers[2] = s2.addr;

        authority = new KernelAuthority(signers, 2);
        registry = new ReleaseRegistry(address(authority));
        factory = new InstanceFactory(address(registry));
    }

    function test_kernelAuthority_owner_factory_controller_end_to_end() public {
        // === Publish releases (owner = KernelAuthority via EIP-1271) ===
        ReleaseRegistry rr = registry;

        bytes32 rootV1 = keccak256("root-v1");
        bytes32 uriHashV1 = keccak256("uri-v1");
        bytes32 metaHashV1 = keccak256("meta-v1");
        _publishAuthorized(rr, COMPONENT_ID, 1, rootV1, uriHashV1, metaHashV1);
        assertTrue(rr.isTrustedRoot(rootV1), "v1 root should be trusted");

        bytes32 rootV2 = keccak256("root-v2");
        bytes32 uriHashV2 = keccak256("uri-v2");
        bytes32 metaHashV2 = keccak256("meta-v2");
        _publishAuthorized(rr, COMPONENT_ID, 2, rootV2, uriHashV2, metaHashV2);
        assertTrue(rr.isTrustedRoot(rootV2), "v2 root should be trusted");

        // === Create instance (root = KernelAuthority via EIP-1271) ===
        bytes32 genesisPolicyHash = keccak256("policy-v1");
        bytes32 salt = keccak256("salt-ic-1");

        uint256 setupDeadline = block.timestamp + 3600;
        bytes32 setupDigest = factory.hashSetupRequest(
            address(authority),
            address(authority),
            address(authority),
            rootV1,
            uriHashV1,
            genesisPolicyHash,
            salt,
            setupDeadline
        );

        bytes memory setupSig = _kaSigBlob(setupDigest);
        address instance = factory.createInstanceDeterministicAuthorized(
            address(authority),
            address(authority),
            address(authority),
            rootV1,
            uriHashV1,
            genesisPolicyHash,
            salt,
            setupDeadline,
            setupSig
        );
        assertTrue(factory.isInstance(instance), "factory must mark instance");

        InstanceController c = InstanceController(instance);
        assertEq(c.rootAuthority(), address(authority), "rootAuthority mismatch");
        assertEq(c.upgradeAuthority(), address(authority), "upgradeAuthority mismatch");
        assertEq(c.emergencyAuthority(), address(authority), "emergencyAuthority mismatch");
        assertEq(c.releaseRegistry(), address(rr), "releaseRegistry mismatch");
        assertEq(c.activeRoot(), rootV1, "activeRoot mismatch");
        assertEq(c.activeUriHash(), uriHashV1, "activeUriHash mismatch");
        assertEq(c.activePolicyHash(), genesisPolicyHash, "activePolicyHash mismatch");

        // === Finalize production (root-only, executed through KernelAuthority.execute) ===
        bytes32 expectedComponentId = COMPONENT_ID;
        bytes memory finalizeData = abi.encodeCall(
            InstanceController.finalizeProduction, (address(rr), expectedComponentId, 60, 10, true, 0, false)
        );
        _executeAsKernelAuthority(instance, finalizeData);

        assertTrue(c.releaseRegistryLocked(), "releaseRegistry should be locked");
        assertTrue(c.expectedComponentIdLocked(), "expectedComponentId should be locked");
        assertTrue(c.minUpgradeDelayLocked(), "minUpgradeDelay should be locked");
        assertTrue(c.maxCheckInAgeLocked(), "maxCheckInAge should be locked");
        assertTrue(c.autoPauseOnBadCheckInLocked(), "autoPauseOnBadCheckIn should be locked");
        assertTrue(c.compatibilityWindowLocked(), "compatibilityWindow should be locked");
        assertTrue(c.emergencyCanUnpauseLocked(), "emergencyCanUnpause should be locked");

        assertEq(c.expectedComponentId(), expectedComponentId, "expectedComponentId mismatch");
        assertEq(c.minUpgradeDelaySec(), 60, "minUpgradeDelaySec mismatch");
        assertEq(c.maxCheckInAgeSec(), 10, "maxCheckInAgeSec mismatch");

        // === Propose upgrade by release (upgrade-only, executed through KernelAuthority.execute) ===
        bytes32 upgradePolicyHash = keccak256("policy-v2");
        bytes memory proposeData = abi.encodeCall(
            InstanceController.proposeUpgradeByRelease, (expectedComponentId, 2, upgradePolicyHash, 100)
        );
        _executeAsKernelAuthority(instance, proposeData);

        (bytes32 pendingRoot, bytes32 pendingUriHash, bytes32 pendingPolicyHash, uint64 createdAt, uint64 ttlSec) =
            c.pendingUpgrade();
        assertEq(pendingRoot, rootV2, "pending root mismatch");
        assertEq(pendingUriHash, uriHashV2, "pending uriHash mismatch");
        assertEq(pendingPolicyHash, upgradePolicyHash, "pending policyHash mismatch");
        assertEq(ttlSec, 100, "pending ttlSec mismatch");
        assertEq(createdAt, uint64(block.timestamp), "createdAt mismatch");

        // === Activation should be timelocked (root-only) ===
        bytes memory activateData = abi.encodeCall(InstanceController.activateUpgrade, ());
        {
            KernelAuthority ka = authority;
            uint256 deadline = block.timestamp + 3600;
            uint256 nonceBefore = ka.nonce();
            bytes32 digest = ka.hashExecute(instance, 0, activateData, nonceBefore, deadline);

            bytes[] memory sigs = new bytes[](2);
            sigs[0] = _signDigest(s0, digest);
            sigs[1] = _signDigest(s1, digest);

            vm.expectRevert(abi.encodeWithSelector(InstanceController.UpgradeTimelocked.selector));
            ka.execute(instance, 0, activateData, deadline, sigs);
        }

        // After minUpgradeDelaySec (set above), activation should succeed.
        vm.warp(uint256(createdAt) + uint256(c.minUpgradeDelaySec()));
        _executeAsKernelAuthority(instance, activateData);

        assertEq(c.activeRoot(), rootV2, "activeRoot should be updated");
        assertEq(c.activeUriHash(), uriHashV2, "activeUriHash should be updated");
        assertEq(c.activePolicyHash(), upgradePolicyHash, "activePolicyHash should be updated");
    }

    function _publishAuthorized(
        ReleaseRegistry rr,
        bytes32 componentId,
        uint64 version,
        bytes32 root,
        bytes32 uriHash,
        bytes32 metaHash
    ) private {
        uint256 deadline = block.timestamp + 3600;
        bytes32 digest = rr.hashPublish(componentId, version, root, uriHash, metaHash, deadline);
        bytes memory sig = _kaSigBlob(digest);
        rr.publishAuthorized(componentId, version, root, uriHash, metaHash, deadline, sig);
    }

    function _executeAsKernelAuthority(address target, bytes memory data) private {
        KernelAuthority ka = authority;

        uint256 deadline = block.timestamp + 3600;
        uint256 nonceBefore = ka.nonce();
        bytes32 digest = ka.hashExecute(target, 0, data, nonceBefore, deadline);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signDigest(s0, digest);
        sigs[1] = _signDigest(s1, digest);

        ka.execute(target, 0, data, deadline, sigs);
    }

    function _kaSigBlob(bytes32 digest) private returns (bytes memory) {
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signDigest(s0, digest);
        sigs[1] = _signDigest(s1, digest);
        return abi.encode(sigs);
    }

    function _signDigest(Signer memory signer, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _sort3(Signer memory a, Signer memory b, Signer memory c) private pure returns (Signer[3] memory) {
        Signer[3] memory s = [a, b, c];
        if (s[0].addr > s[1].addr) {
            (s[0], s[1]) = (s[1], s[0]);
        }
        if (s[1].addr > s[2].addr) {
            (s[1], s[2]) = (s[2], s[1]);
        }
        if (s[0].addr > s[1].addr) {
            (s[0], s[1]) = (s[1], s[0]);
        }
        return s;
    }
}
