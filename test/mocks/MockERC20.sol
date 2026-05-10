// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20,Ownable{

    constructor(string memory name,string memory symbol) ERC20(name,symbol){
        _mint(msg.sender, 100000 * 10**18);
    }

    function mint(address to,uint256 amount) external onlyOwner{
        _mint(to, amount);
    }
    
}