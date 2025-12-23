pragma solidity ^0.8.24;

/// @notice Optional on-chain blob store for manifests (paranoid “full detail” mode).
/// @dev Skeleton contract (not audited, not production-ready).
///
/// Design goals:
/// - Append-only, chunked storage keyed by an off-chain content hash (`blobHash`).
/// - Owner-gated writes to prevent third-party sabotage of official blobs.
/// - No on-chain recomputation of the content hash (done off-chain; consumers MUST verify).
contract ManifestStore {
    struct BlobMeta {
        uint64 chunkCount;
        uint64 totalBytes;
        bool finalized;
    }

    address public owner;
    address public pendingOwner;

    mapping(bytes32 => BlobMeta) private blobs;
    mapping(bytes32 => mapping(uint64 => bytes)) private chunks;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed pendingOwner);

    event ChunkAppended(bytes32 indexed blobHash, uint64 indexed index, bytes32 chunkKeccak, uint32 size);
    event BlobFinalized(bytes32 indexed blobHash, uint64 chunkCount, uint64 totalBytes);

    modifier onlyOwner() {
        require(msg.sender == owner, "ManifestStore: not owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "ManifestStore: owner=0");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ManifestStore: owner=0");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "ManifestStore: not pending owner");
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    function getMeta(bytes32 blobHash) external view returns (uint64 chunkCount, uint64 totalBytes, bool finalized) {
        BlobMeta memory meta = blobs[blobHash];
        return (meta.chunkCount, meta.totalBytes, meta.finalized);
    }

    function getChunk(bytes32 blobHash, uint64 index) external view returns (bytes memory) {
        BlobMeta memory meta = blobs[blobHash];
        require(index < meta.chunkCount, "ManifestStore: index out of range");
        return chunks[blobHash][index];
    }

    function appendChunk(bytes32 blobHash, bytes calldata chunk) external onlyOwner returns (uint64 index) {
        require(blobHash != bytes32(0), "ManifestStore: blobHash=0");
        require(chunk.length != 0, "ManifestStore: empty chunk");

        BlobMeta storage meta = blobs[blobHash];
        require(!meta.finalized, "ManifestStore: finalized");

        index = meta.chunkCount;
        chunks[blobHash][index] = chunk;

        meta.chunkCount = index + 1;
        meta.totalBytes += uint64(chunk.length);

        emit ChunkAppended(blobHash, index, keccak256(chunk), uint32(chunk.length));
    }

    function finalize(bytes32 blobHash, uint64 expectedChunkCount, uint64 expectedTotalBytes) external onlyOwner {
        require(blobHash != bytes32(0), "ManifestStore: blobHash=0");

        BlobMeta storage meta = blobs[blobHash];
        require(!meta.finalized, "ManifestStore: finalized");
        require(meta.chunkCount != 0, "ManifestStore: empty blob");

        require(meta.chunkCount == expectedChunkCount, "ManifestStore: chunkCount mismatch");
        require(meta.totalBytes == expectedTotalBytes, "ManifestStore: totalBytes mismatch");

        meta.finalized = true;
        emit BlobFinalized(blobHash, meta.chunkCount, meta.totalBytes);
    }
}

