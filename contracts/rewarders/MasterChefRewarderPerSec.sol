// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "../libs/SafeMath.sol";
import "../libs/Address.sol";
import "../libs/Ownable.sol";
import "../libs/SafeERC20.sol";

interface IRewarder {
    using SafeERC20 for IERC20;

    function onNETTReward(address user, uint256 newLpAmount) external;

    function pendingTokens(address user) external view returns (uint256 pending);

    function rewardToken() external view returns (IERC20);
}

interface IMasterChef {
    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool. Reward token to distribute per block.
    }

    function deposit(uint256 _pid, uint256 _amount) external;

    function poolInfo(uint256 pid) external view returns (IMasterChef.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);
}

interface INETTFarm {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this poolInfo.
        uint256 lastRewardTimestamp; // Last block timestamp that NETT distribution occurs.
        uint256 accNETTPerShare; // Accumulated NETT per share, times 1e12.
        uint256 lpSupply;
    }

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
}

/**
 * This is a sample contract to be used in the NETTFarm contract for partners to reward
 * stakers with their native token alongside NETT.
 *
 * It assumes the project already has an existing MasterChef-style farm contract.
 * In which case, the init() function is called to deposit a dummy token into one
 * of the MasterChef farms so this contract can accrue rewards from that farm.
 * The contract then transfers the reward token to the user on each call to
 * onNETTReward().
 *
 */
 contract MasterChefRewarderPerSec is IRewarder, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable override rewardToken;
    IERC20 public immutable lpToken;
    uint256 public immutable MCV1_pid;
    IMasterChef public immutable MCV1;
    INETTFarm public immutable NTF;

    /// @notice Info of each NTF user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of NETT entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each NTF poolInfo.
    /// `accTokenPerShare` Amount of NETT each LP token is worth.
    /// `lastRewardTimestamp` The last time NETT was rewarded to the poolInfo.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTimestamp;
        uint256 allocPoint;
    }

    /// @notice Info of the poolInfo.
    PoolInfo public poolInfo;
    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public tokenPerSec;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AllocPointUpdated(uint256 oldAllocPoint, uint256 newAllocPoint);

    modifier onlyNTF() {
        require(msg.sender == address(NTF), "onlyNTF: only NETTFarm can call this function");
        _;
    }

    constructor(
        IERC20 _rewardToken,
        IERC20 _lpToken,
        uint256 _tokenPerSec,
        uint256 _allocPoint,
        uint256 _MCV1_pid,
        IMasterChef _MCV1,
        INETTFarm _NTF
    ) public {
        require(Address.isContract(address(_rewardToken)), "constructor: reward token must be a valid contract");
        require(Address.isContract(address(_lpToken)), "constructor: LP token must be a valid contract");
        require(Address.isContract(address(_MCV1)), "constructor: MasterChef must be a valid contract");
        require(Address.isContract(address(_NTF)), "constructor: NETTFarm must be a valid contract");

        rewardToken = _rewardToken;
        lpToken = _lpToken;
        tokenPerSec = _tokenPerSec;
        MCV1_pid = _MCV1_pid;
        MCV1 = _MCV1;
        NTF = _NTF;
        poolInfo = PoolInfo({lastRewardTimestamp: block.timestamp, accTokenPerShare: 0, allocPoint: _allocPoint});
    }

    /// @notice Deposits a dummy token to a MaterChefV1 farm so that this contract can claim reward tokens.
    /// @param dummyToken The address of the dummy ERC20 token to deposit into MCV1.
    function init(IERC20 dummyToken) external {
        uint256 balance = dummyToken.balanceOf(msg.sender);
        require(balance > 0, "init: Balance must exceed 0");
        dummyToken.safeTransferFrom(msg.sender, address(this), balance);
        dummyToken.approve(address(MCV1), balance);
        MCV1.deposit(MCV1_pid, balance);
    }

    /// @notice Update reward variables of the given poolInfo.
    /// @return pool Returns the pool that was updated.
    function updatePool() public returns (PoolInfo memory pool) {
        pool = poolInfo;

        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = lpToken.balanceOf(address(NTF));

            if (lpSupply > 0) {
                uint256 timeElapsed = block.timestamp.sub(pool.lastRewardTimestamp);
                uint256 tokenReward = timeElapsed.mul(tokenPerSec).mul(pool.allocPoint).div(MCV1.totalAllocPoint());
                pool.accTokenPerShare = pool.accTokenPerShare.add((tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply));
            }

            pool.lastRewardTimestamp = block.timestamp;
            poolInfo = pool;
        }
    }

    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerSec The number of tokens to distribute per block
    function setRewardRate(uint256 _tokenPerSec) external onlyOwner {
        updatePool();

        uint256 oldRate = tokenPerSec;
        tokenPerSec = _tokenPerSec;

        emit RewardRateUpdated(oldRate, _tokenPerSec);
    }

    /// @notice Sets the allocation point. THis will also update the poolInfo.
    /// @param _allocPoint The new allocation point of the pool
    function setAllocPoint(uint256 _allocPoint) external onlyOwner {
        updatePool();

        uint256 oldAllocPoint = poolInfo.allocPoint;
        poolInfo.allocPoint = _allocPoint;

        emit AllocPointUpdated(oldAllocPoint, _allocPoint);
    }

    /// @notice Claims reward tokens from MCV1 farm.
    function harvestFromMasterChefV1() public {
        MCV1.deposit(MCV1_pid, 0);
    }

    /// @notice Function called by NETTFarm whenever staker claims NETT harvest. Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _lpAmount Number of LP tokens the user has
    function onNETTReward(address _user, uint256 _lpAmount) external override onlyNTF {
        updatePool();
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 pendingBal;
        // if user had deposited
        if (user.amount > 0) {
            harvestFromMasterChefV1();
            pendingBal = (user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt);
            uint256 rewardBal = rewardToken.balanceOf(address(this));
            if (pendingBal > rewardBal) {
                rewardToken.safeTransfer(_user, rewardBal);
            } else {
                rewardToken.safeTransfer(_user, pendingBal);
            }
        }

        user.amount = _lpAmount;
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION;

        emit OnReward(_user, pendingBal);
    }

    /// @notice View function to see pending tokens
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingTokens(address _user) external view override returns (uint256 pending) {
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = lpToken.balanceOf(address(NTF));

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 blocks = block.timestamp.sub(pool.lastRewardTimestamp);
            uint256 tokenReward = blocks.mul(tokenPerSec).mul(pool.allocPoint).div(MCV1.totalAllocPoint());
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }

        pending = (user.amount.mul(accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt);
    }
 }