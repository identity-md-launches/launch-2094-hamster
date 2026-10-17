// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {HamsterToken} from "../../src/HamsterToken.sol";

/// @dev Test fixture for a contract that deploys and distributes the launch supply.
contract TokenFactory {
    function deploy(bytes32 salt) external returns (HamsterToken) {
        return new HamsterToken{salt: salt}();
    }

    function distribute(HamsterToken token, address recipient, uint256 amount) external {
        require(token.transfer(recipient, amount), "transfer failed");
    }
}
