// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "../libs/BoringNETTERC20.sol";

interface INETTFarm {
    using BoringNETTERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. NETT to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that NETT distribution occurs.
        uint256 accNETTPerShare; // Accumulated NETT per share, times 1e12. See below.
    }

    function userInfo(uint256 _pid, address _user) external view returns (INETTFarm.UserInfo memory);

    function poolInfo(uint256 pid) external view returns (INETTFarm.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function nettPerSec() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
}