pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {ReleaseRegistry} from "../src/ReleaseRegistry.sol";

contract ReleaseRegistryTest is TestBase {
    address private owner = address(0x1111111111111111111111111111111111111111);
    address private other = address(0x2222222222222222222222222222222222222222);

    function test_constructor_sets_owner() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);
        assertEq(registry.owner(), owner, "owner mismatch");
    }

    function test_constructor_rejects_zero_owner() public {
        vm.expectRevert("ReleaseRegistry: owner=0");
        new ReleaseRegistry(address(0));
    }

    function test_publish_only_owner() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32 component = keccak256("blackcat-core");
        uint64 version = 1;
        bytes32 root = keccak256("root");
        bytes32 uriHash = keccak256("uri");
        bytes32 metaHash = keccak256("meta");

        vm.prank(other);
        vm.expectRevert("ReleaseRegistry: not owner");
        registry.publish(component, version, root, uriHash, metaHash);

        vm.prank(owner);
        registry.publish(component, version, root, uriHash, metaHash);

        ReleaseRegistry.Release memory rel = registry.get(component, version);
        assertEq(rel.root, root, "root mismatch");
        assertEq(rel.uriHash, uriHash, "uriHash mismatch");
        assertEq(rel.metaHash, metaHash, "metaHash mismatch");
    }

    function test_transferOwnership_only_owner() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        vm.prank(other);
        vm.expectRevert("ReleaseRegistry: not owner");
        registry.transferOwnership(other);

        vm.prank(owner);
        registry.transferOwnership(other);

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: not pending owner");
        registry.acceptOwnership();

        vm.prank(other);
        registry.acceptOwnership();
        assertEq(registry.owner(), other, "owner not transferred");
    }

    function test_publish_rejects_invalid_values() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: componentId=0");
        registry.publish(bytes32(0), 1, keccak256("root"), 0, 0);

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: version=0");
        registry.publish(keccak256("c"), 0, keccak256("root"), 0, 0);

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: root=0");
        registry.publish(keccak256("c"), 1, bytes32(0), 0, 0);
    }

    function test_publish_is_immutable_per_component_version() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32 component = keccak256("blackcat-core");
        uint64 version = 1;
        bytes32 root = keccak256("root");

        vm.prank(owner);
        registry.publish(component, version, root, 0, 0);

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: already published");
        registry.publish(component, version, keccak256("root2"), 0, 0);
    }

    function test_publish_rejects_root_reuse_across_releases() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32 componentA = keccak256("blackcat-core");
        bytes32 componentB = keccak256("blackcat-crypto");
        bytes32 root = keccak256("root");

        vm.prank(owner);
        registry.publish(componentA, 1, root, keccak256("uri"), keccak256("meta"));

        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: root already published");
        registry.publish(componentB, 1, root, keccak256("uri2"), keccak256("meta2"));
    }

    function test_publishBatch_publishes_multiple_releases() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32[] memory components = new bytes32[](2);
        uint64[] memory versions = new uint64[](2);
        bytes32[] memory roots = new bytes32[](2);
        bytes32[] memory uriHashes = new bytes32[](2);
        bytes32[] memory metaHashes = new bytes32[](2);

        components[0] = keccak256("blackcat-core");
        components[1] = keccak256("blackcat-crypto");
        versions[0] = 1;
        versions[1] = 1;
        roots[0] = keccak256("root-1");
        roots[1] = keccak256("root-2");
        uriHashes[0] = keccak256("uri-1");
        uriHashes[1] = keccak256("uri-2");
        metaHashes[0] = keccak256("meta-1");
        metaHashes[1] = keccak256("meta-2");

        vm.prank(owner);
        registry.publishBatch(components, versions, roots, uriHashes, metaHashes);

        ReleaseRegistry.Release memory rel1 = registry.get(components[0], versions[0]);
        assertEq(rel1.root, roots[0], "rel1 root mismatch");

        (bytes32 c, uint64 v, bytes32 u, bytes32 m, bool revoked) = registry.getByRoot(roots[1]);
        assertEq(c, components[1], "component mismatch");
        assertEq(uint256(v), uint256(versions[1]), "version mismatch");
        assertEq(u, uriHashes[1], "uriHash mismatch");
        assertEq(m, metaHashes[1], "metaHash mismatch");
        assertTrue(!revoked, "revoked should be false");
    }

    function test_revoke_marks_root_untrusted() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32 component = keccak256("blackcat-core");
        uint64 version = 1;
        bytes32 root = keccak256("root");

        vm.prank(owner);
        registry.publish(component, version, root, 0, 0);
        assertTrue(registry.isTrustedRoot(root), "root should be trusted after publish");

        vm.prank(owner);
        registry.revoke(component, version);

        assertTrue(registry.isPublishedRoot(root), "root should remain published");
        assertTrue(registry.isRevokedRoot(root), "root should be revoked");
        assertTrue(registry.isRevokedRelease(component, version), "release should be revoked");
        assertTrue(!registry.isTrustedRoot(root), "root should not be trusted after revoke");

        bytes32 otherComponent = keccak256("blackcat-crypto");
        vm.prank(owner);
        vm.expectRevert("ReleaseRegistry: root revoked");
        registry.publish(otherComponent, 1, root, 0, 0);
    }

    function test_revokeByRoot_revokes_release() public {
        ReleaseRegistry registry = new ReleaseRegistry(owner);

        bytes32 component = keccak256("blackcat-core");
        bytes32 root = keccak256("root");

        vm.prank(owner);
        registry.publish(component, 1, root, 0, 0);
        assertTrue(registry.isTrustedRoot(root), "root should be trusted");

        vm.prank(owner);
        registry.revokeByRoot(root);

        assertTrue(registry.isRevokedRoot(root), "root should be revoked");
        assertTrue(!registry.isTrustedRoot(root), "root should not be trusted");
    }
}
