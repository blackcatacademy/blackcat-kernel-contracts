pragma solidity ^0.8.24;

/// @dev Minimal Foundry cheatcodes interface (no external dependencies).
interface FoundryVm {
    function envUint(string calldata name) external returns (uint256);
    function envAddress(string calldata name) external returns (address);
    function envBytes32(string calldata name) external returns (bytes32);

    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

