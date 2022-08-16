// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

/// @title Vote Escrow ERC20 Token Interface
/// @notice Interface of a ERC20 token used for vote escrow and boosted farm. Notice that transfers and
/// allowances are disabled
interface IVeERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}