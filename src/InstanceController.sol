pragma solidity ^0.8.24;

interface IReleaseRegistry {
    function isTrustedRoot(bytes32 root) external view returns (bool);
}

/// @notice Per-install trust authority for a single BlackCat deployment.
/// @dev Skeleton contract (not audited, not production-ready).
contract InstanceController {
    uint8 public constant VERSION = 1;
    uint64 public constant MAX_UPGRADE_DELAY_SEC = 30 days;

    struct UpgradeProposal {
        bytes32 root;
        bytes32 uriHash;
        bytes32 policyHash;
        uint64 createdAt;
        uint64 ttlSec;
    }

    /// @notice Factory or caller that initialized this instance (provenance hint).
    address public factory;

    address public rootAuthority;
    address public upgradeAuthority;
    address public emergencyAuthority;
    address public pendingRootAuthority;
    address public pendingUpgradeAuthority;
    address public pendingEmergencyAuthority;

    address public releaseRegistry;
    address public reporterAuthority;
    address public pendingReporterAuthority;

    bool public paused;
    bool public autoPauseOnBadCheckIn;

    bytes32 public activeRoot;
    bytes32 public activeUriHash;
    bytes32 public activePolicyHash;

    UpgradeProposal public pendingUpgrade;

    uint64 public genesisAt;
    uint64 public lastUpgradeAt;
    uint64 public minUpgradeDelaySec;
    uint64 public lastCheckInAt;
    bool public lastCheckInOk;

    uint64 public incidentCount;
    uint64 public lastIncidentAt;
    bytes32 public lastIncidentHash;
    address public lastIncidentBy;

    event Initialized(
        address indexed factory,
        address indexed rootAuthority,
        address indexed upgradeAuthority,
        address emergencyAuthority
    );
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event UpgradeProposed(bytes32 root, bytes32 uriHash, bytes32 policyHash, uint64 ttlSec);
    event UpgradeCanceled(address indexed by);
    event UpgradeActivated(bytes32 previousRoot, bytes32 root, bytes32 uriHash, bytes32 policyHash);
    event RootAuthorityChanged(address indexed previousValue, address indexed newValue);
    event UpgradeAuthorityChanged(address indexed previousValue, address indexed newValue);
    event EmergencyAuthorityChanged(address indexed previousValue, address indexed newValue);
    event RootAuthorityTransferStarted(address indexed previousValue, address indexed pendingValue);
    event UpgradeAuthorityTransferStarted(address indexed previousValue, address indexed pendingValue);
    event EmergencyAuthorityTransferStarted(address indexed previousValue, address indexed pendingValue);
    event ReporterAuthorityTransferStarted(address indexed previousValue, address indexed pendingValue);
    event RootAuthorityTransferCanceled(address indexed previousValue, address indexed pendingValue);
    event UpgradeAuthorityTransferCanceled(address indexed previousValue, address indexed pendingValue);
    event EmergencyAuthorityTransferCanceled(address indexed previousValue, address indexed pendingValue);
    event ReporterAuthorityTransferCanceled(address indexed previousValue, address indexed pendingValue);
    event ReleaseRegistryChanged(address indexed previousValue, address indexed newValue);
    event ReporterAuthorityChanged(address indexed previousValue, address indexed newValue);
    event MinUpgradeDelayChanged(uint64 previousValue, uint64 newValue);
    event AutoPauseOnBadCheckInChanged(bool previousValue, bool newValue);
    event CheckIn(address indexed by, bool ok, bytes32 observedRoot, bytes32 observedUriHash, bytes32 observedPolicyHash);
    event IncidentReported(address indexed by, bytes32 incidentHash, uint64 at);

    modifier onlyRootAuthority() {
        require(msg.sender == rootAuthority, "InstanceController: not root authority");
        _;
    }

    modifier onlyUpgradeAuthority() {
        require(msg.sender == upgradeAuthority, "InstanceController: not upgrade authority");
        _;
    }

    modifier onlyEmergencyAuthority() {
        require(msg.sender == emergencyAuthority, "InstanceController: not emergency authority");
        _;
    }

    modifier onlyEmergencyOrRootAuthority() {
        require(
            msg.sender == emergencyAuthority || msg.sender == rootAuthority,
            "InstanceController: not emergency/root authority"
        );
        _;
    }

    modifier onlyReporterAuthority() {
        require(msg.sender == reporterAuthority, "InstanceController: not reporter authority");
        _;
    }

    modifier onlyRootOrUpgradeAuthority() {
        require(
            msg.sender == rootAuthority || msg.sender == upgradeAuthority,
            "InstanceController: not root/upgrade authority"
        );
        _;
    }

    /// @dev Lock the implementation instance (clones do not execute constructors).
    constructor() {
        rootAuthority = address(1);
    }

    /// @dev This initializer is intended for clones (EIP-1167).
    function initialize(
        address rootAuthority_,
        address upgradeAuthority_,
        address emergencyAuthority_,
        address releaseRegistry_,
        bytes32 genesisRoot,
        bytes32 genesisUriHash,
        bytes32 genesisPolicyHash
    ) external {
        require(rootAuthority == address(0), "InstanceController: already initialized");
        require(rootAuthority_ != address(0), "InstanceController: root=0");
        require(upgradeAuthority_ != address(0), "InstanceController: upgrade=0");
        require(emergencyAuthority_ != address(0), "InstanceController: emergency=0");
        require(genesisRoot != bytes32(0), "InstanceController: genesisRoot=0");

        factory = msg.sender;
        rootAuthority = rootAuthority_;
        upgradeAuthority = upgradeAuthority_;
        emergencyAuthority = emergencyAuthority_;

        if (releaseRegistry_ != address(0)) {
            require(releaseRegistry_.code.length != 0, "InstanceController: registry not contract");
            require(
                IReleaseRegistry(releaseRegistry_).isTrustedRoot(genesisRoot),
                "InstanceController: genesis root not trusted"
            );
            releaseRegistry = releaseRegistry_;
        }

        genesisAt = uint64(block.timestamp);
        lastUpgradeAt = genesisAt;

        activeRoot = genesisRoot;
        activeUriHash = genesisUriHash;
        activePolicyHash = genesisPolicyHash;

        emit Initialized(factory, rootAuthority_, upgradeAuthority_, emergencyAuthority_);
        emit UpgradeActivated(bytes32(0), genesisRoot, genesisUriHash, genesisPolicyHash);
    }

    function pause() external onlyEmergencyOrRootAuthority {
        if (!paused) {
            paused = true;
            emit Paused(msg.sender);
        }
    }

    function unpause() external onlyEmergencyOrRootAuthority {
        if (paused) {
            paused = false;
            emit Unpaused(msg.sender);
        }
    }

    function startRootAuthorityTransfer(address newValue) external onlyRootAuthority {
        require(newValue != address(0), "InstanceController: root=0");
        pendingRootAuthority = newValue;
        emit RootAuthorityTransferStarted(rootAuthority, newValue);
    }

    function cancelRootAuthorityTransfer() external onlyRootAuthority {
        address pendingValue = pendingRootAuthority;
        require(pendingValue != address(0), "InstanceController: no pending root");
        pendingRootAuthority = address(0);
        emit RootAuthorityTransferCanceled(rootAuthority, pendingValue);
    }

    function acceptRootAuthority() external {
        address pendingValue = pendingRootAuthority;
        require(pendingValue != address(0), "InstanceController: no pending root");
        require(msg.sender == pendingValue, "InstanceController: not pending root");
        address previousValue = rootAuthority;
        rootAuthority = pendingValue;
        pendingRootAuthority = address(0);
        emit RootAuthorityChanged(previousValue, pendingValue);
    }

    function startUpgradeAuthorityTransfer(address newValue) external onlyRootAuthority {
        require(newValue != address(0), "InstanceController: upgrade=0");
        pendingUpgradeAuthority = newValue;
        emit UpgradeAuthorityTransferStarted(upgradeAuthority, newValue);
    }

    function cancelUpgradeAuthorityTransfer() external onlyRootAuthority {
        address pendingValue = pendingUpgradeAuthority;
        require(pendingValue != address(0), "InstanceController: no pending upgrade");
        pendingUpgradeAuthority = address(0);
        emit UpgradeAuthorityTransferCanceled(upgradeAuthority, pendingValue);
    }

    function acceptUpgradeAuthority() external {
        address pendingValue = pendingUpgradeAuthority;
        require(pendingValue != address(0), "InstanceController: no pending upgrade");
        require(msg.sender == pendingValue, "InstanceController: not pending upgrade");
        address previousValue = upgradeAuthority;
        upgradeAuthority = pendingValue;
        pendingUpgradeAuthority = address(0);
        emit UpgradeAuthorityChanged(previousValue, pendingValue);
    }

    function startEmergencyAuthorityTransfer(address newValue) external onlyRootAuthority {
        require(newValue != address(0), "InstanceController: emergency=0");
        pendingEmergencyAuthority = newValue;
        emit EmergencyAuthorityTransferStarted(emergencyAuthority, newValue);
    }

    function cancelEmergencyAuthorityTransfer() external onlyRootAuthority {
        address pendingValue = pendingEmergencyAuthority;
        require(pendingValue != address(0), "InstanceController: no pending emergency");
        pendingEmergencyAuthority = address(0);
        emit EmergencyAuthorityTransferCanceled(emergencyAuthority, pendingValue);
    }

    function acceptEmergencyAuthority() external {
        address pendingValue = pendingEmergencyAuthority;
        require(pendingValue != address(0), "InstanceController: no pending emergency");
        require(msg.sender == pendingValue, "InstanceController: not pending emergency");
        address previousValue = emergencyAuthority;
        emergencyAuthority = pendingValue;
        pendingEmergencyAuthority = address(0);
        emit EmergencyAuthorityChanged(previousValue, pendingValue);
    }

    function setReleaseRegistry(address newValue) external onlyRootAuthority {
        if (newValue != address(0)) {
            require(newValue.code.length != 0, "InstanceController: registry not contract");
            require(
                IReleaseRegistry(newValue).isTrustedRoot(activeRoot),
                "InstanceController: active root not trusted"
            );

            UpgradeProposal memory p = pendingUpgrade;
            if (p.root != bytes32(0)) {
                require(
                    IReleaseRegistry(newValue).isTrustedRoot(p.root),
                    "InstanceController: pending root not trusted"
                );
            }
        }
        address previousValue = releaseRegistry;
        releaseRegistry = newValue;
        emit ReleaseRegistryChanged(previousValue, newValue);
    }

    function startReporterAuthorityTransfer(address newValue) external onlyRootAuthority {
        require(newValue != address(0), "InstanceController: reporter=0");
        pendingReporterAuthority = newValue;
        emit ReporterAuthorityTransferStarted(reporterAuthority, newValue);
    }

    function cancelReporterAuthorityTransfer() external onlyRootAuthority {
        address pendingValue = pendingReporterAuthority;
        require(pendingValue != address(0), "InstanceController: no pending reporter");
        pendingReporterAuthority = address(0);
        emit ReporterAuthorityTransferCanceled(reporterAuthority, pendingValue);
    }

    function acceptReporterAuthority() external {
        address pendingValue = pendingReporterAuthority;
        require(pendingValue != address(0), "InstanceController: no pending reporter");
        require(msg.sender == pendingValue, "InstanceController: not pending reporter");
        address previousValue = reporterAuthority;
        reporterAuthority = pendingValue;
        pendingReporterAuthority = address(0);
        emit ReporterAuthorityChanged(previousValue, pendingValue);
    }

    function clearReporterAuthority() external onlyRootAuthority {
        address previousValue = reporterAuthority;
        reporterAuthority = address(0);
        pendingReporterAuthority = address(0);
        emit ReporterAuthorityChanged(previousValue, address(0));
    }

    function setMinUpgradeDelaySec(uint64 newValue) external onlyRootAuthority {
        require(newValue <= MAX_UPGRADE_DELAY_SEC, "InstanceController: delay too large");
        uint64 previousValue = minUpgradeDelaySec;
        minUpgradeDelaySec = newValue;
        emit MinUpgradeDelayChanged(previousValue, newValue);
    }

    function setAutoPauseOnBadCheckIn(bool newValue) external onlyRootAuthority {
        bool previousValue = autoPauseOnBadCheckIn;
        autoPauseOnBadCheckIn = newValue;
        emit AutoPauseOnBadCheckInChanged(previousValue, newValue);
    }

    function checkIn(bytes32 observedRoot, bytes32 observedUriHash, bytes32 observedPolicyHash)
        external
        onlyReporterAuthority
    {
        bool ok = (!paused)
            && (observedRoot == activeRoot)
            && (observedUriHash == activeUriHash)
            && (observedPolicyHash == activePolicyHash);

        lastCheckInAt = uint64(block.timestamp);
        lastCheckInOk = ok;

        emit CheckIn(msg.sender, ok, observedRoot, observedUriHash, observedPolicyHash);

        if (autoPauseOnBadCheckIn && !paused && !ok) {
            _recordIncident(
                msg.sender,
                keccak256(
                    abi.encodePacked(
                        "bad_checkin",
                        observedRoot,
                        observedUriHash,
                        observedPolicyHash,
                        activeRoot,
                        activeUriHash,
                        activePolicyHash
                    )
                )
            );
            paused = true;
            emit Paused(msg.sender);
        }
    }

    function reportIncident(bytes32 incidentHash) external {
        require(incidentHash != bytes32(0), "InstanceController: incidentHash=0");
        require(
            msg.sender == rootAuthority
                || msg.sender == emergencyAuthority
                || msg.sender == reporterAuthority,
            "InstanceController: not incident reporter"
        );

        _recordIncident(msg.sender, incidentHash);

        if (!paused) {
            paused = true;
            emit Paused(msg.sender);
        }
    }

    function proposeUpgrade(bytes32 root, bytes32 uriHash, bytes32 policyHash, uint64 ttlSec)
        external
        onlyUpgradeAuthority
    {
        require(root != bytes32(0), "InstanceController: root=0");
        require(ttlSec != 0, "InstanceController: ttl=0");

        address registry = releaseRegistry;
        if (registry != address(0)) {
            require(IReleaseRegistry(registry).isTrustedRoot(root), "InstanceController: root not trusted");
        }

        pendingUpgrade = UpgradeProposal({
            root: root, uriHash: uriHash, policyHash: policyHash, createdAt: uint64(block.timestamp), ttlSec: ttlSec
        });

        emit UpgradeProposed(root, uriHash, policyHash, ttlSec);
    }

    function cancelUpgrade() external onlyRootOrUpgradeAuthority {
        UpgradeProposal memory upgrade = pendingUpgrade;
        require(upgrade.root != bytes32(0), "InstanceController: no pending upgrade");
        delete pendingUpgrade;
        emit UpgradeCanceled(msg.sender);
    }

    function activateUpgrade() external onlyRootAuthority {
        require(!paused, "InstanceController: paused");
        UpgradeProposal memory upgrade = pendingUpgrade;
        require(upgrade.root != bytes32(0), "InstanceController: no pending upgrade");
        require(
            block.timestamp >= uint256(upgrade.createdAt) + uint256(minUpgradeDelaySec),
            "InstanceController: upgrade timelocked"
        );
        require(
            block.timestamp <= uint256(upgrade.createdAt) + uint256(upgrade.ttlSec),
            "InstanceController: upgrade expired"
        );

        address registry = releaseRegistry;
        if (registry != address(0)) {
            require(
                IReleaseRegistry(registry).isTrustedRoot(upgrade.root),
                "InstanceController: root not trusted"
            );
        }

        bytes32 previousRoot = activeRoot;
        activeRoot = upgrade.root;
        activeUriHash = upgrade.uriHash;
        activePolicyHash = upgrade.policyHash;

        delete pendingUpgrade;

        lastUpgradeAt = uint64(block.timestamp);

        emit UpgradeActivated(previousRoot, activeRoot, activeUriHash, activePolicyHash);
    }

    function _recordIncident(address by, bytes32 incidentHash) private {
        incidentCount += 1;
        lastIncidentAt = uint64(block.timestamp);
        lastIncidentHash = incidentHash;
        lastIncidentBy = by;
        emit IncidentReported(by, incidentHash, uint64(block.timestamp));
    }

    function snapshot()
        external
        view
        returns (
            uint8 version,
            bool paused_,
            bytes32 activeRoot_,
            bytes32 activeUriHash_,
            bytes32 activePolicyHash_,
            bytes32 pendingRoot_,
            bytes32 pendingUriHash_,
            bytes32 pendingPolicyHash_,
            uint64 pendingCreatedAt_,
            uint64 pendingTtlSec_,
            uint64 genesisAt_,
            uint64 lastUpgradeAt_
        )
    {
        UpgradeProposal memory p = pendingUpgrade;
        return (
            VERSION,
            paused,
            activeRoot,
            activeUriHash,
            activePolicyHash,
            p.root,
            p.uriHash,
            p.policyHash,
            p.createdAt,
            p.ttlSec,
            genesisAt,
            lastUpgradeAt
        );
    }
}
