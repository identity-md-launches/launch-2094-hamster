// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {HamsterToken} from "src/HamsterToken.sol";

/// @notice Sequence and arithmetic properties supplementing the deployment and ERC-20 examples.
/// forge-config: default.fuzz.runs = 1000
contract HamsterTokenPropertiesTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    HamsterToken private token;
    address private alice;
    address private bob;
    address private spender;

    function setUp() public {
        token = new HamsterToken();
        alice = makeAddr("properties alice");
        bob = makeAddr("properties bob");
        spender = makeAddr("properties spender");
    }

    function test_oneWeiDelegatedTransferCanBeReturned() public {
        assertTrue(token.approve(spender, 1));
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), alice, 1);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.allowance(address(this), spender), 0);

        vm.prank(alice);
        assertTrue(token.transfer(address(this), 1));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_fullSupplyCanMoveWithExactDelegatedApproval() public {
        assertTrue(token.approve(spender, SUPPLY));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.allowance(address(this), spender), 0);

        // Refunding the owner does not restore an exhausted spending permission.
        vm.prank(alice);
        assertTrue(token.transfer(address(this), 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.balanceOf(address(this)), 1);
        assertEq(token.balanceOf(alice), SUPPLY - 1);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_largestFiniteAllowanceIsDecremented() public {
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 2);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, SUPPLY - 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 1 - SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ownerMustApproveItselfBeforeUsingTransferFrom() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), alice, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);

        assertTrue(token.approve(address(this), 1));
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.balanceOf(alice), 1);
    }

    function testFuzz_roundTripPreservesFundedBalancesAndApprovals(
        uint256 balanceSeed,
        uint256 amountSeed,
        uint256 aliceApproval,
        uint256 bobApproval
    ) public {
        uint256 aliceBalance = bound(balanceSeed, 0, SUPPLY);
        uint256 amount = bound(amountSeed, 0, aliceBalance);
        assertTrue(token.transfer(alice, aliceBalance));
        assertTrue(token.transfer(bob, SUPPLY - aliceBalance));
        vm.prank(alice);
        assertTrue(token.approve(spender, aliceApproval));
        vm.prank(bob);
        assertTrue(token.approve(spender, bobApproval));

        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));
        assertEq(token.balanceOf(alice), aliceBalance - amount);
        assertEq(token.balanceOf(bob), SUPPLY - aliceBalance + amount);
        vm.prank(bob);
        assertTrue(token.transfer(alice, amount));

        assertEq(token.balanceOf(alice), aliceBalance);
        assertEq(token.balanceOf(bob), SUPPLY - aliceBalance);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.allowance(alice, spender), aliceApproval);
        assertEq(token.allowance(bob, spender), bobApproval);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitDelegatedTransferMatchesSingleTransfer(
        uint256 firstSeed,
        uint256 secondSeed,
        uint256 approvalSeed
    ) public {
        HamsterToken single = new HamsterToken();
        uint256 first = bound(firstSeed, 0, SUPPLY);
        uint256 second = bound(secondSeed, 0, SUPPLY - first);
        uint256 approved = bound(approvalSeed, first + second, type(uint256).max);
        assertTrue(token.approve(spender, approved));
        assertTrue(single.approve(spender, approved));

        vm.startPrank(spender);
        assertTrue(token.transferFrom(address(this), alice, first));
        assertTrue(token.transferFrom(address(this), alice, second));
        assertTrue(single.transferFrom(address(this), alice, first + second));
        vm.stopPrank();

        // Compare two ways of performing the same movement, including the approval state.
        assertEq(token.balanceOf(alice), single.balanceOf(alice));
        assertEq(token.balanceOf(address(this)), single.balanceOf(address(this)));
        assertEq(token.allowance(address(this), spender), single.allowance(address(this), spender));
        assertEq(token.balanceOf(alice), first + second);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(single.totalSupply(), SUPPLY);
    }

    function testFuzz_replacingInfiniteApprovalUsesFiniteBudget(uint256 approvalSeed, uint256 amountSeed) public {
        uint256 approved = bound(approvalSeed, 0, type(uint256).max - 1);
        uint256 available = approved < SUPPLY ? approved : SUPPLY;
        uint256 amount = bound(amountSeed, 0, available);
        assertTrue(token.approve(spender, type(uint256).max));
        assertTrue(token.approve(spender, approved));
        assertEq(token.allowance(address(this), spender), approved);

        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, amount));
        assertEq(token.allowance(address(this), spender), approved - amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);

        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
    }

    function testFuzz_failedDelegatedTransferCanBeRetriedAfterFunding(uint256 amountSeed, uint256 approvalSeed) public {
        uint256 amount = bound(amountSeed, 1, SUPPLY);
        uint256 approved = bound(approvalSeed, amount, type(uint256).max);
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);

        assertTrue(token.transfer(alice, amount));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(token.allowance(alice, spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_unlimitedApprovalCannotOverdrawEvenOnSelfTransfer(uint256 balanceSeed, uint256 excessSeed)
        public
    {
        uint256 balance = bound(balanceSeed, 0, SUPPLY);
        uint256 amount = balance + bound(excessSeed, 1, type(uint256).max - balance);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, type(uint256).max));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(spender);
        token.transferFrom(alice, alice, amount);
        assertEq(token.allowance(alice, spender), type(uint256).max);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_zeroDelegatedTransferPreservesExistingApproval(uint256 approved) public {
        assertTrue(token.approve(spender, approved));
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), alice, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 0));
        assertEq(token.allowance(address(this), spender), approved);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
