// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./VeERC20.sol";

interface IBoostedNETTFarm {
    function updateFactor(address, uint256) external;
}

/// @title Vote Escrow NETT - veNETT
/// @notice Infinite supply, used to receive extra farming yields and voting power
contract VeNETT is VeERC20("VeNETT", "veNETT"), Ownable {
    /// @notice the BoostedNETTFarm contract
    IBoostedNETTFarm public boostedNETTFarm;

    event UpdateBoostedNETTFarm(address indexed user, address boostedNETTFarm);

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (VeNETTStaking)
    /// @param _to The address that will receive the mint
    /// @param _amount The amount to be minted
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `_from`. Callable only by the owner (VeNETTStaking)
    /// @param _from The address that will burn tokens
    /// @param _amount The amount to be burned
    function burnFrom(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }

    /// @dev Sets the address of the BoostedNETTFarm contract this updates
    /// @param _boostedNETTFarm the address of BoostedFarm
    function setBoostedNETTFarm(address _boostedNETTFarm) external onlyOwner {
        // We allow 0 address here if we want to disable the callback operations
        boostedNETTFarm = IBoostedNETTFarm(_boostedNETTFarm);

        emit UpdateBoostedNETTFarm(_msgSender(), _boostedNETTFarm);
    }

    function _afterTokenOperation(address _account, uint256 _newBalance) internal override {
        if (address(boostedNETTFarm) != address(0)) {
            boostedNETTFarm.updateFactor(_account, _newBalance);
        }
    }

    function renounceOwnership() public override onlyOwner {
        revert("VeNETT: Cannot renounce, can only transfer ownership");
    }
}