// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 decimal;
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        decimal = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }        

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }       
}