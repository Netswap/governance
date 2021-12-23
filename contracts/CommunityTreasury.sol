// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Custodian of community's NETT. Deploy this contract, then change the owner to be a
 * governance protocol. Send community treasury funds to the deployed contract, then
 * spend them through governance proposals.
 */
contract CommunityTreasury is Ownable {
    using SafeERC20 for IERC20;

    // Token to custody
    IERC20 public NETT;

    constructor(address NETT_) public {
        NETT = IERC20(NETT_);
    }

    /**
     * Transfer NETT to the destination. Can only be called by the contract owner.
     */
    function transfer(address dest, uint amount) external onlyOwner {
        NETT.safeTransfer(dest, amount);
    }

    /**
     * Return the NETT balance of this contract.
     */
    function balance() view external returns(uint) {
        return NETT.balanceOf(address(this));
    }

}