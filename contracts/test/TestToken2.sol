// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * Simple token contract for running tests
 */
contract TestToken2 is ERC20 {
    constructor() ERC20("TestToken2", "TT2") {
        mint(msg.sender, 100 ether);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
