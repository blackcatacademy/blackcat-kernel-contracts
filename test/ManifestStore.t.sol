pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {ManifestStore} from "../src/ManifestStore.sol";

contract ManifestStoreTest is TestBase {
    address private owner = address(0x1111111111111111111111111111111111111111);
    address private other = address(0x2222222222222222222222222222222222222222);

    function test_constructor_rejects_zero_owner() public {
        vm.expectRevert("ManifestStore: owner=0");
        new ManifestStore(address(0));
    }

    function test_append_and_finalize_and_getChunk() public {
        ManifestStore store = new ManifestStore(owner);
        bytes32 blob = keccak256("blob");

        vm.prank(owner);
        uint64 idx0 = store.appendChunk(blob, bytes("hello"));
        assertEq(uint256(idx0), 0, "idx0 mismatch");

        vm.prank(owner);
        uint64 idx1 = store.appendChunk(blob, bytes("world"));
        assertEq(uint256(idx1), 1, "idx1 mismatch");

        (uint64 chunkCount, uint64 totalBytes, bool finalized) = store.getMeta(blob);
        assertEq(uint256(chunkCount), 2, "chunkCount mismatch");
        assertEq(uint256(totalBytes), 10, "totalBytes mismatch");
        assertTrue(!finalized, "should not be finalized");

        vm.prank(owner);
        store.finalize(blob, 2, 10);

        (,, finalized) = store.getMeta(blob);
        assertTrue(finalized, "should be finalized");

        bytes memory c0 = store.getChunk(blob, 0);
        bytes memory c1 = store.getChunk(blob, 1);
        require(keccak256(c0) == keccak256(bytes("hello")), "chunk0 mismatch");
        require(keccak256(c1) == keccak256(bytes("world")), "chunk1 mismatch");
    }

    function test_append_only_owner() public {
        ManifestStore store = new ManifestStore(owner);
        vm.prank(other);
        vm.expectRevert("ManifestStore: not owner");
        store.appendChunk(keccak256("blob"), bytes("x"));
    }

    function test_finalize_only_owner() public {
        ManifestStore store = new ManifestStore(owner);
        bytes32 blob = keccak256("blob");

        vm.prank(owner);
        store.appendChunk(blob, bytes("x"));

        vm.prank(other);
        vm.expectRevert("ManifestStore: not owner");
        store.finalize(blob, 1, 1);
    }

    function test_finalize_rejects_mismatch() public {
        ManifestStore store = new ManifestStore(owner);
        bytes32 blob = keccak256("blob");

        vm.prank(owner);
        store.appendChunk(blob, bytes("x"));

        vm.prank(owner);
        vm.expectRevert("ManifestStore: chunkCount mismatch");
        store.finalize(blob, 2, 1);

        vm.prank(owner);
        vm.expectRevert("ManifestStore: totalBytes mismatch");
        store.finalize(blob, 1, 2);
    }

    function test_append_rejects_after_finalize() public {
        ManifestStore store = new ManifestStore(owner);
        bytes32 blob = keccak256("blob");

        vm.prank(owner);
        store.appendChunk(blob, bytes("x"));

        vm.prank(owner);
        store.finalize(blob, 1, 1);

        vm.prank(owner);
        vm.expectRevert("ManifestStore: finalized");
        store.appendChunk(blob, bytes("y"));
    }

    function test_ownership_transfer_two_step() public {
        ManifestStore store = new ManifestStore(owner);

        vm.prank(owner);
        store.transferOwnership(other);

        vm.prank(other);
        store.acceptOwnership();

        vm.prank(other);
        store.appendChunk(keccak256("blob"), bytes("x"));
    }
}

