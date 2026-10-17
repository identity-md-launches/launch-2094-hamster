// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title HAMSTER
/// @notice Fixed-supply token for the HAMSTER project (@hamsterhourgame).
/// @dev The immediate deployer receives all tokens. There are no administrative powers
///      or externally callable mint/burn functions after construction.
contract HamsterToken is ERC20 {
    /// @notice One billion HAMSTER, expressed in the token's 18-decimal base units.
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("HAMSTER", "HAMSTER") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
