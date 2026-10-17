// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {HamsterToken} from "../src/HamsterToken.sol";

/// @dev A closed set of holders with an independent balance and allowance ledger.
contract HamsterHandler is Test {
    HamsterToken public immutable token;
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    address[4] public actors;
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor() {
        actors = [makeAddr("holder A"), makeAddr("holder B"), makeAddr("holder C"), makeAddr("holder D")];
        token = new HamsterToken();
        require(token.transfer(actors[0], SUPPLY));
        expectedBalance[actors[0]] = SUPPLY;
    }

    function transfer(uint8 fromSeed, uint8 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % 4];
        address to = actors[toSeed % 4];
        uint256 amount = bound(amountSeed, 0, expectedBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
    }

    function approve(uint8 ownerSeed, uint8 spenderSeed, uint256 amountSeed, bool unlimited) external {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        // Approval is independent of the owner's balance and may exceed the whole supply.
        uint256 amount = unlimited ? type(uint256).max : amountSeed;
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function transferFrom(uint8 ownerSeed, uint8 spenderSeed, uint8 toSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        address to = actors[toSeed % 4];
        uint256 allowance = expectedAllowance[owner][spender];
        uint256 available = expectedBalance[owner];
        if (allowance < available) available = allowance;
        uint256 amount = bound(amountSeed, 0, available);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        expectedBalance[owner] -= amount;
        expectedBalance[to] += amount;
        if (allowance != type(uint256).max) expectedAllowance[owner][spender] -= amount;
    }

    function overdraw(uint8 fromSeed, uint8 toSeed, uint256 excessSeed) external {
        address from = actors[fromSeed % 4];
        address to = actors[toSeed % 4];
        uint256 balance = expectedBalance[from];
        uint256 amount = balance + bound(excessSeed, 1, type(uint256).max - balance);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(from);
        token.transfer(to, amount);
        // Failed operations must leave the independent ledger and the token unchanged.
    }

    function approveAndSpend(uint8 ownerSeed, uint8 spenderSeed, uint8 toSeed, uint256 amountSeed, bool unlimited)
        external
    {
        // Always exercise a positive delegated transfer, even if other holders have been emptied.
        address owner = _fundedActor(ownerSeed);
        address spender = actors[spenderSeed % 4];
        address to = actors[toSeed % 4];
        uint256 amount = bound(amountSeed, 1, expectedBalance[owner]);
        _approveFor(owner, spender, unlimited ? type(uint256).max : amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        expectedBalance[owner] -= amount;
        expectedBalance[to] += amount;
        if (!unlimited) expectedAllowance[owner][spender] = 0;
    }

    function revokeAndAttemptSpend(uint8 ownerSeed, uint8 spenderSeed, uint8 toSeed) external {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        address to = actors[toSeed % 4];
        _approveFor(owner, spender, 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(owner, to, 1);
    }

    function exceedAllowance(uint8 ownerSeed, uint8 spenderSeed, uint8 toSeed, uint256 approvalSeed) external {
        address owner = _fundedActor(ownerSeed);
        address spender = actors[spenderSeed % 4];
        address to = actors[toSeed % 4];
        // The owner can afford the movement: only the insufficient permission can reject it.
        uint256 approved = bound(approvalSeed, 0, expectedBalance[owner] - 1);
        _approveFor(owner, spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, approved + 1)
        );
        vm.prank(spender);
        token.transferFrom(owner, to, approved + 1);
    }

    function overdrawFrom(uint8 ownerSeed, uint8 spenderSeed, uint8 toSeed, uint256 excessSeed, bool unlimited)
        external
    {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        address to = actors[toSeed % 4];
        uint256 balance = expectedBalance[owner];
        uint256 amount = balance + bound(excessSeed, 1, type(uint256).max - balance);
        _approveFor(owner, spender, unlimited ? type(uint256).max : amount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount));
        vm.prank(spender);
        token.transferFrom(owner, to, amount);
        // The invariants also check that a finite allowance spend was rolled back.
    }

    function transferToZero(uint8 ownerSeed, uint8 spenderSeed, uint256 amountSeed, bool delegated) external {
        address owner = actors[ownerSeed % 4];
        address spender = actors[spenderSeed % 4];
        uint256 amount = bound(amountSeed, 0, expectedBalance[owner]);
        if (delegated) {
            _approveFor(owner, spender, amount);
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(spender);
            token.transferFrom(owner, address(0), amount);
        } else {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(owner);
            token.transfer(address(0), amount);
        }
    }

    function approveZeroSpender(uint8 ownerSeed, uint256 amount) external {
        address owner = actors[ownerSeed % 4];
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(owner);
        token.approve(address(0), amount);
    }

    function _approveFor(address owner, address spender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function _fundedActor(uint8 seed) private view returns (address) {
        for (uint256 i; i < 4; ++i) {
            address actor = actors[(uint256(seed) + i) % 4];
            if (expectedBalance[actor] > 0) return actor;
        }
        revert("the conserved supply must have a holder");
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract HamsterTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    HamsterHandler private handler;
    HamsterToken private token;

    function setUp() public {
        handler = new HamsterHandler();
        token = handler.token();
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = HamsterHandler.transfer.selector;
        selectors[1] = HamsterHandler.approve.selector;
        selectors[2] = HamsterHandler.transferFrom.selector;
        selectors[3] = HamsterHandler.overdraw.selector;
        selectors[4] = HamsterHandler.approveAndSpend.selector;
        selectors[5] = HamsterHandler.revokeAndAttemptSpend.selector;
        selectors[6] = HamsterHandler.exceedAllowance.selector;
        selectors[7] = HamsterHandler.overdrawFrom.selector;
        selectors[8] = HamsterHandler.transferToZero.selector;
        selectors[9] = HamsterHandler.approveZeroSpender.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_supplyRemainsFixed() public view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
    }

    function invariant_balancesMatchLedgerAndConserveSupply() public view {
        uint256 total;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            uint256 balance = token.balanceOf(actor);
            assertEq(balance, handler.expectedBalance(actor));
            total += balance;
        }
        assertEq(total, SUPPLY);
    }

    function invariant_allowancesMatchLedger() public view {
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            assertEq(token.allowance(actor, address(0)), 0);
            assertEq(token.allowance(address(0), actor), 0);
            for (uint256 j; j < 4; ++j) {
                address owner = handler.actors(i);
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.expectedAllowance(owner, spender));
            }
        }
    }
}
