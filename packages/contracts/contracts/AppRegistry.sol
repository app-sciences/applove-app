// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AppRegistry
/// @notice Registers AppLove projects (apps whose developers opted in). Third-party apps discovered
/// from public charts stay off-chain and are never registered here.
contract AppRegistry is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    struct Project {
        address admin;
        string appleAppId; // numeric App Store id, "" if none
        string googlePackage; // e.g. com.example.app, "" if none
        bytes32 metadataHash; // hash of off-chain registration metadata
        bytes32 oracleConfig; // reference to off-chain oracle configuration
        bool revenueSharing;
    }

    uint256 public projectCount;
    mapping(uint256 projectId => Project) private _projects;
    mapping(bytes32 storeKey => uint256 projectId) public projectByStoreKey;

    event ProjectRegistered(uint256 indexed projectId, address indexed admin, string appleAppId, string googlePackage, bytes32 metadataHash);
    event RevenueSharingSet(uint256 indexed projectId, bool enabled);
    event MetadataUpdated(uint256 indexed projectId, bytes32 metadataHash);
    event OracleConfigUpdated(uint256 indexed projectId, bytes32 oracleConfig);

    error UnknownProject(uint256 projectId);
    error StoreIdAlreadyRegistered(bytes32 storeKey, uint256 existingProjectId);
    error NoStoreId();
    error ZeroAddress();
    error NotProjectAdmin();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

    function registerProject(
        address projectAdmin,
        string calldata appleAppId,
        string calldata googlePackage,
        bytes32 metadataHash,
        bytes32 oracleConfig
    ) external onlyRole(REGISTRAR_ROLE) returns (uint256 projectId) {
        if (projectAdmin == address(0)) revert ZeroAddress();
        if (bytes(appleAppId).length == 0 && bytes(googlePackage).length == 0) revert NoStoreId();
        projectId = ++projectCount;
        if (bytes(appleAppId).length != 0) _claimStoreKey(keccak256(abi.encode("apple", appleAppId)), projectId);
        if (bytes(googlePackage).length != 0) _claimStoreKey(keccak256(abi.encode("google", googlePackage)), projectId);
        _projects[projectId] = Project(projectAdmin, appleAppId, googlePackage, metadataHash, oracleConfig, false);
        emit ProjectRegistered(projectId, projectAdmin, appleAppId, googlePackage, metadataHash);
    }

    function setRevenueSharing(uint256 projectId, bool enabled) external onlyRole(REGISTRAR_ROLE) {
        _requireExists(projectId);
        _projects[projectId].revenueSharing = enabled;
        emit RevenueSharingSet(projectId, enabled);
    }

    function setOracleConfig(uint256 projectId, bytes32 oracleConfig) external onlyRole(REGISTRAR_ROLE) {
        _requireExists(projectId);
        _projects[projectId].oracleConfig = oracleConfig;
        emit OracleConfigUpdated(projectId, oracleConfig);
    }

    function updateMetadata(uint256 projectId, bytes32 metadataHash) external {
        _requireExists(projectId);
        if (msg.sender != _projects[projectId].admin && !hasRole(REGISTRAR_ROLE, msg.sender)) revert NotProjectAdmin();
        _projects[projectId].metadataHash = metadataHash;
        emit MetadataUpdated(projectId, metadataHash);
    }

    function getProject(uint256 projectId) external view returns (Project memory) {
        _requireExists(projectId);
        return _projects[projectId];
    }

    function exists(uint256 projectId) public view returns (bool) {
        return projectId != 0 && projectId <= projectCount;
    }

    function isRevenueSharingActive(uint256 projectId) external view returns (bool) {
        return exists(projectId) && _projects[projectId].revenueSharing;
    }

    function _claimStoreKey(bytes32 key, uint256 projectId) private {
        uint256 existing = projectByStoreKey[key];
        if (existing != 0) revert StoreIdAlreadyRegistered(key, existing);
        projectByStoreKey[key] = projectId;
    }

    function _requireExists(uint256 projectId) private view {
        if (!exists(projectId)) revert UnknownProject(projectId);
    }
}
