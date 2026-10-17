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
        uint256 amount = unlimited ? type(uint256).max : bound(amountSeed, 0, SUPPLY);
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
}

contract HamsterTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    HamsterHandler private handler;
    HamsterToken private token;

    function setUp() public {
        handler = new HamsterHandler();
        token = handler.token();
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = HamsterHandler.transfer.selector;
        selectors[1] = HamsterHandler.approve.selector;
        selectors[2] = HamsterHandler.transferFrom.selector;
        selectors[3] = HamsterHandler.overdraw.selector;
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
            for (uint256 j; j < 4; ++j) {
                address owner = handler.actors(i);
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.expectedAllowance(owner, spender));
            }
        }
    }
}
