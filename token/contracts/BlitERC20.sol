
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Blit is ERC20, Ownable {
    constructor() ERC20("Blit", "BLIT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}