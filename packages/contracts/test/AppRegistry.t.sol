// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {AppRegistry} from "../contracts/AppRegistry.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AppRegistryTest is Base {
    function test_register_storesProjectAndIncrementsId() public {
        uint256 id = appRegistry.registerProject(dev, "123", "com.example.app", keccak256("m"), keccak256("o"));
        assertEq(id, 1);
        AppRegistry.Project memory p = appRegistry.getProject(id);
        assertEq(p.admin, dev);
        assertEq(p.appleAppId, "123");
        assertEq(p.googlePackage, "com.example.app");
        assertFalse(p.revenueSharing);
        assertFalse(appRegistry.isRevenueSharingActive(id));
        assertEq(appRegistry.registerProject(dev, "456", "", 0, 0), 2);
    }

    function test_register_rejectsDuplicateStoreIds() public {
        appRegistry.registerProject(dev, "123", "com.example.app", 0, 0);
        vm.expectRevert();
        appRegistry.registerProject(dev, "123", "", 0, 0);
        vm.expectRevert();
        appRegistry.registerProject(dev, "", "com.example.app", 0, 0);
    }

    function test_register_rejectsMissingStoreIdAndZeroAdmin() public {
        vm.expectRevert(AppRegistry.NoStoreId.selector);
        appRegistry.registerProject(dev, "", "", 0, 0);
        vm.expectRevert(AppRegistry.ZeroAddress.selector);
        appRegistry.registerProject(address(0), "1", "", 0, 0);
    }

    function test_onlyRegistrar() public {
        bytes32 role = appRegistry.REGISTRAR_ROLE();
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        appRegistry.registerProject(stranger, "1", "", 0, 0);
        vm.stopPrank();
        uint256 id = appRegistry.registerProject(dev, "1", "", 0, 0);
        vm.prank(stranger);
        vm.expectRevert();
        appRegistry.setRevenueSharing(id, true);
    }

    function test_metadata_updatableByProjectAdminOnly() public {
        uint256 id = appRegistry.registerProject(dev, "1", "", 0, 0);
        vm.prank(dev);
        appRegistry.updateMetadata(id, keccak256("v2"));
        assertEq(appRegistry.getProject(id).metadataHash, keccak256("v2"));
        vm.prank(stranger);
        vm.expectRevert(AppRegistry.NotProjectAdmin.selector);
        appRegistry.updateMetadata(id, keccak256("evil"));
    }

    function test_unknownProjectReverts() public {
        vm.expectRevert(abi.encodeWithSelector(AppRegistry.UnknownProject.selector, 99));
        appRegistry.getProject(99);
        vm.expectRevert(abi.encodeWithSelector(AppRegistry.UnknownProject.selector, 0));
        appRegistry.setRevenueSharing(0, true);
        assertFalse(appRegistry.isRevenueSharingActive(99));
    }

    function test_oracleConfig_updatableByRegistrar() public {
        uint256 id = appRegistry.registerProject(dev, "1", "", 0, 0);
        appRegistry.setOracleConfig(id, keccak256("cfg-v2"));
        assertEq(appRegistry.getProject(id).oracleConfig, keccak256("cfg-v2"));
        vm.prank(dev);
        vm.expectRevert();
        appRegistry.setOracleConfig(id, 0);
    }
}
