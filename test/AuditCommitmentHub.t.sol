/*
 * SPDX-FileCopyrightText: 2025 Black Cat Academy s. r. o.
 * SPDX-License-Identifier: LicenseRef-BlackCat-Proprietary-1.0
 */

pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {AuditCommitmentHub} from "../src/AuditCommitmentHub.sol";
import {InstanceController} from "../src/InstanceController.sol";
import {InstanceFactory} from "../src/InstanceFactory.sol";
import {KernelAuthority} from "../src/KernelAuthority.sol";

contract AuditCommitmentHubTest is TestBase {
    struct Signer {
        address addr;
        uint256 pk;
    }

    Signer private s0;
    Signer private s1;

    KernelAuthority private authority;
    InstanceFactory private factory;
    AuditCommitmentHub private hub;
    InstanceController private instance;

    function setUp() public {
        Signer memory a = Signer({pk: 0xA11CE, addr: vm.addr(0xA11CE)});
        Signer memory b = Signer({pk: 0xB0B, addr: vm.addr(0xB0B)});
        (Signer memory sa, Signer memory sb) = _sort2(a, b);
        s0 = sa;
        s1 = sb;

        address[] memory signers = new address[](2);
        signers[0] = s0.addr;
        signers[1] = s1.addr;
        authority = new KernelAuthority(signers, 2);

        factory = new InstanceFactory(address(0));
        address instanceAddr = factory.createInstance(
            address(this), address(this), address(this), keccak256("genesisRoot"), keccak256("uri"), keccak256("policy")
        );
        instance = InstanceController(instanceAddr);

        instance.startReporterAuthorityTransfer(address(authority));
        vm.prank(address(authority));
        instance.acceptReporterAuthority();

        hub = new AuditCommitmentHub();
    }

    function test_commit_rejects_when_reporter_not_set() public {
        InstanceFactory f = new InstanceFactory(address(0));
        address addr = f.createInstance(
            address(this),
            address(this),
            address(this),
            keccak256("genesisRoot2"),
            keccak256("uri2"),
            keccak256("policy2")
        );

        vm.expectRevert("AuditCommitmentHub: reporter not set");
        hub.commit(addr, 1, 1, keccak256("root"), 0);
    }

    function test_commit_allows_direct_reporter_sender_and_enforces_seq() public {
        address inst = address(instance);

        vm.prank(address(authority));
        hub.commit(inst, 1, 100, keccak256("root-1"), 0);
        assertEq(hub.lastSeq(inst), 100, "lastSeq mismatch");

        vm.prank(address(authority));
        vm.expectRevert("AuditCommitmentHub: seq mismatch");
        hub.commit(inst, 102, 200, keccak256("root-2"), 0);
    }

    function test_commitAuthorized_accepts_kernelAuthority_reporter_signature() public {
        address inst = address(instance);

        vm.prank(address(authority));
        hub.commit(inst, 1, 10, keccak256("root-1"), 0);

        uint256 deadline = block.timestamp + 3600;
        bytes32 merkleRoot = keccak256("root-2");
        bytes32 metaHash = keccak256("meta-2");
        bytes32 digest = hub.hashCommit(inst, 11, 20, merkleRoot, metaHash, deadline);

        bytes memory sigBlob = _kaSigBlob(digest);
        hub.commitAuthorized(inst, 11, 20, merkleRoot, metaHash, deadline, sigBlob);

        assertEq(hub.lastSeq(inst), 20, "lastSeq mismatch");
    }

    function test_commitAuthorized_rejects_insufficient_kernelAuthority_signatures() public {
        address inst = address(instance);
        uint256 deadline = block.timestamp + 3600;

        bytes32 merkleRoot = keccak256("root");
        bytes32 digest = hub.hashCommit(inst, 1, 1, merkleRoot, 0, deadline);

        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _sign(s0.pk, digest);
        bytes memory sigBlob = abi.encode(sigs);

        vm.expectRevert("AuditCommitmentHub: invalid reporter signature");
        hub.commitAuthorized(inst, 1, 1, merkleRoot, 0, deadline, sigBlob);
    }

    function _sort2(Signer memory a, Signer memory b) private pure returns (Signer memory, Signer memory) {
        if (a.addr < b.addr) {
            return (a, b);
        }
        return (b, a);
    }

    function _kaSigBlob(bytes32 digest) private returns (bytes memory) {
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(s0.pk, digest);
        sigs[1] = _sign(s1.pk, digest);
        return abi.encode(sigs);
    }

    function _sign(uint256 pk, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }
}

