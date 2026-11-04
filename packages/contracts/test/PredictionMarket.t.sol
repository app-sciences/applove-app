// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {PredictionMarket} from "../contracts/PredictionMarket.sol";
import {PredictionMarketFactory} from "../contracts/PredictionMarketFactory.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReentrantTrader is IERC1155Receiver {
    PredictionMarket public market;
    bool public reentrySucceeded;
    uint256 public attempts;

    constructor(PredictionMarket m) {
        market = m;
    }

    function buy(uint256 amount) external {
        market.collateral().approve(address(market), type(uint256).max);
        market.mintSets(amount);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        attempts++;
        try market.mergeSets(1) {
            reentrySucceeded = true;
        } catch {}
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

contract PredictionMarketTest is Base {
    PredictionMarket m;

    function setUp() public override {
        super.setUp();
        m = _market(2, 100); // YES/NO, 1% fee
    }

    // ---------------------------------------------------------- factory

    function test_factory_onlyCreator() public {
        PredictionMarketFactory.MarketParams memory p = _params(2, 0);
        vm.prank(stranger);
        vm.expectRevert();
        factory.createMarket(p);
    }

    function test_factory_validatesTerms() public {
        PredictionMarketFactory.MarketParams memory p = _params(2, 0);
        p.collateral = address(0xBEEF);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarketFactory.CollateralNotAllowed.selector, address(0xBEEF)));
        factory.createMarket(p);

        p = _params(1, 0);
        vm.expectRevert(PredictionMarketFactory.InvalidOutcomeCount.selector);
        factory.createMarket(p);
        p = _params(9, 0);
        vm.expectRevert(PredictionMarketFactory.InvalidOutcomeCount.selector);
        factory.createMarket(p);

        p = _params(2, 501);
        vm.expectRevert(PredictionMarketFactory.FeeTooHigh.selector);
        factory.createMarket(p);

        p = _params(2, 0);
        p.closeTime = uint64(block.timestamp);
        vm.expectRevert(PredictionMarketFactory.InvalidTimes.selector);
        factory.createMarket(p);

        p = _params(2, 0);
        p.resolveBy = p.closeTime; // shorter than minResolutionWindow
        vm.expectRevert(PredictionMarketFactory.InvalidTimes.selector);
        factory.createMarket(p);

        p = _params(2, 0);
        p.termsHash = bytes32(0);
        vm.expectRevert(PredictionMarketFactory.EmptyTerms.selector);
        factory.createMarket(p);
    }

    function test_factory_zeroAddresses_rejected() public {
        vm.expectRevert(PredictionMarketFactory.ZeroAddress.selector);
        new PredictionMarketFactory(admin, address(0), address(treasury), 1 days);
        vm.expectRevert(PredictionMarketFactory.ZeroAddress.selector);
        new PredictionMarketFactory(admin, address(predOracle), address(0), 1 days);
        vm.expectRevert(PredictionMarketFactory.ZeroAddress.selector);
        factory.setCollateralAllowed(address(0), true);
    }

    function test_factory_recordsImmutableTerms() public view {
        assertTrue(factory.isMarket(address(m)));
        assertEq(factory.marketCount(), 1);
        assertEq(m.oracle(), address(predOracle));
        assertEq(m.treasury(), address(treasury));
        assertEq(m.outcomeCount(), 2);
        assertEq(m.feeBps(), 100);
        assertEq(address(m.collateral()), address(usdc));
    }

    // ---------------------------------------------------------- trading

    function test_mintSets_chargesFee_locksCollateral() public {
        uint256 sets = _buySets(m, alice, 1_000e6);
        assertEq(sets, 990e6);
        assertEq(m.balanceOf(alice, 0), 990e6);
        assertEq(m.balanceOf(alice, 1), 990e6);
        assertEq(m.lockedCollateral(), 990e6);
        assertEq(usdc.balanceOf(address(m)), 990e6);
        assertEq(usdc.balanceOf(address(treasury)), 10e6);
    }

    function test_mergeSets_returnsCollateral() public {
        _buySets(m, alice, 1_000e6);
        vm.prank(alice);
        m.mergeSets(490e6);
        assertEq(usdc.balanceOf(alice), 490e6);
        assertEq(m.lockedCollateral(), 500e6);
    }

    function test_merge_requiresCompleteSet() public {
        _buySets(m, alice, 1_000e6);
        vm.prank(alice);
        m.safeTransferFrom(alice, bob, 0, 990e6, ""); // alice now only holds NO
        vm.prank(alice);
        vm.expectRevert();
        m.mergeSets(1);
    }

    function test_insufficientCollateral_reverts() public {
        usdc.mint(alice, 10e6);
        vm.startPrank(alice);
        usdc.approve(address(m), 100e6);
        vm.expectRevert();
        m.mintSets(100e6);
        vm.stopPrank();
        assertEq(m.lockedCollateral(), 0);
    }

    function test_zeroAmount_reverts() public {
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        m.mintSets(0);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        m.mergeSets(0);
    }

    function test_deadline_blocksNewPositions() public {
        vm.warp(m.closeTime());
        usdc.mint(alice, 1e6);
        vm.startPrank(alice);
        usdc.approve(address(m), 1e6);
        vm.expectRevert(PredictionMarket.TradingClosed.selector);
        m.mintSets(1e6);
        vm.stopPrank();
    }

    function test_reentrancy_blocked() public {
        ReentrantTrader t = new ReentrantTrader(m);
        usdc.mint(address(t), 100e6);
        t.buy(100e6);
        assertEq(t.attempts(), 1);
        assertFalse(t.reentrySucceeded());
        assertEq(m.lockedCollateral(), 99e6);
    }

    // ---------------------------------------------------------- settlement

    function test_resolve_onlyOracle_afterClose() public {
        vm.expectRevert(PredictionMarket.OnlyOracle.selector);
        m.resolve(0);
        vm.prank(address(predOracle));
        vm.expectRevert(PredictionMarket.TooEarly.selector);
        m.resolve(0);
        vm.warp(m.closeTime());
        vm.prank(address(predOracle));
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.InvalidOutcome.selector, 2));
        m.resolve(2);
    }

    function test_winnersRedeemOneForOne_losersGetNothing_noDoubleRedeem() public {
        _buySets(m, alice, 1_000e6);
        vm.prank(alice);
        m.safeTransferFrom(alice, bob, 0, 990e6, ""); // Bob holds YES, Alice holds NO
        vm.warp(m.closeTime());
        vm.prank(address(predOracle));
        m.resolve(0); // YES wins

        vm.prank(bob);
        assertEq(m.redeem(), 990e6);
        assertEq(usdc.balanceOf(bob), 990e6);
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NothingToRedeem.selector);
        m.redeem();
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.NothingToRedeem.selector);
        m.redeem();
        assertEq(m.lockedCollateral(), 0);
        assertEq(usdc.balanceOf(address(m)), 0);
    }

    function test_noTradingOrMergeAfterResolution() public {
        _buySets(m, alice, 100e6);
        vm.warp(m.closeTime());
        vm.prank(address(predOracle));
        m.resolve(1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.WrongState.selector, PredictionMarket.State.Resolved));
        m.mergeSets(1);
    }

    function test_cancel_refundsEveryHolderProportionally() public {
        PredictionMarket m4 = _market(4, 0);
        _buySets(m4, alice, 400e6);
        // Alice gives Bob all of outcome 2 and 3
        vm.startPrank(alice);
        m4.safeTransferFrom(alice, bob, 2, 400e6, "");
        m4.safeTransferFrom(alice, bob, 3, 400e6, "");
        vm.stopPrank();
        vm.prank(address(predOracle));
        m4.cancel();
        vm.prank(alice);
        assertEq(m4.redeem(), 200e6);
        vm.prank(bob);
        assertEq(m4.redeem(), 200e6);
        assertEq(usdc.balanceOf(address(m4)), 0);
    }

    function test_cancel_permissions() public {
        vm.prank(stranger);
        vm.expectRevert(PredictionMarket.OnlyOracle.selector);
        m.cancel();
        vm.warp(m.resolveBy() + 1); // oracle never resolved -> anyone can trigger refunds
        vm.prank(stranger);
        m.cancel();
        assertEq(uint8(m.state()), uint8(PredictionMarket.State.Cancelled));
    }

    function test_redeemWhileOpen_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.WrongState.selector, PredictionMarket.State.Open));
        m.redeem();
    }

    function testFuzz_solvency_anyFlowPaysAtMostCollateral(uint256 a, uint256 b, uint256 give, uint8 winner, bool cancelIt)
        public
    {
        PredictionMarket m3 = _market(3, 250);
        a = bound(a, 1, 1_000_000e6);
        b = bound(b, 1, 1_000_000e6);
        uint256 sa = _buySets(m3, alice, a);
        _buySets(m3, bob, b);
        give = bound(give, 0, sa);
        vm.prank(alice);
        m3.safeTransferFrom(alice, carol, 1, give, "");
        vm.warp(m3.closeTime());
        if (cancelIt) {
            vm.prank(address(predOracle));
            m3.cancel();
        } else {
            vm.prank(address(predOracle));
            m3.resolve(winner % 3);
        }
        uint256 held = usdc.balanceOf(address(m3));
        uint256 paid;
        address[3] memory who = [alice, bob, carol];
        for (uint256 i = 0; i < 3; ++i) {
            vm.prank(who[i]);
            try m3.redeem() returns (uint256 p) {
                paid += p;
            } catch {}
        }
        assertLe(paid, held);
        assertEq(usdc.balanceOf(address(m3)), held - paid);
        assertEq(m3.lockedCollateral(), held - paid);
    }
}
