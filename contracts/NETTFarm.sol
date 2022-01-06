// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./libs/Ownable.sol";
import "./libs/SafeMath.sol";
import "./libs/SafeERC20.sol";
import "./libs/EnumerableSet.sol";
import "./libs/Address.sol";
import "./libs/BoringERC20.sol";

interface NETT {
    function mint(address _to, uint256 _amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IRewarder {
    using SafeERC20 for IERC20;

    function onNETTReward(address user, uint256 newLpAmount) external;

    function pendingTokens(address user) external view returns (uint256 pending);

    function rewardToken() external view returns (address);
}

// NETTFarm is the birth place of NETT. Farmers can harvest NETT farily from the farm.
// Based on https://github.com/traderjoe-xyz/joe-core/blob/main/contracts/MasterChefJoeV2.sol
contract NETTFarm is Ownable {
    using SafeMath for uint256;
    using BoringERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of NETTs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accNETTPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accNETTPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. NETTs to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that NETTs distribution occurs.
        uint256 accNETTPerShare; // Accumulated NETTs per share, times 1e12. See below.
        uint256 lpSupply;
        IRewarder rewarder;
    }

    // The NETT token!
    NETT public nett;
    // Dev address
    address public devAddr;
    // Percentage of pool rewards that goto the devs. Divided by 100.
    uint256 public devPercent = 10;
    // NETT tokens created per second.
    uint256 public nettPerSec;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Set of all LP tokens that have been added as pools
    EnumerableSet.AddressSet private lpTokens;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The timestamp when NETT mining starts.
    uint256 public startTimestamp;

    event Add(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event Set(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardTimestamp, uint256 lpSupply, uint256 accNETTPerShare);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetDevAddress(address indexed oldAddress, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 _nettPerSec);

    constructor(
        NETT _nett,
        address _devAddr,
        uint256 _nettPerSec,
        uint256 _startTimestamp
    ) public {
        nett = _nett;
        devAddr = _devAddr;
        nettPerSec = _nettPerSec;
        startTimestamp = _startTimestamp;
        totalAllocPoint = 0;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        IRewarder _rewarder
    ) public onlyOwner {
        require(Address.isContract(address(_lpToken)), "add: LP token must be a valid contract");
        require(
            Address.isContract(address(_rewarder)) || address(_rewarder) == address(0),
            "add: rewarder must be contract or zero"
        );
        require(!lpTokens.contains(address(_lpToken)), "add: LP already added");
        massUpdatePools();
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accNETTPerShare: 0,
                rewarder: _rewarder,
                lpSupply: 0
            })
        );
        lpTokens.add(address(_lpToken));
        emit Add(poolInfo.length.sub(1), _allocPoint, _lpToken, _rewarder);
    }

    // Update the given pool's NETT allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        IRewarder _rewarder,
        bool overwrite
    ) public onlyOwner {
        require(
            Address.isContract(address(_rewarder)) || address(_rewarder) == address(0),
            "set: rewarder must be contract or zero"
        );
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        if (overwrite) {
            poolInfo[_pid].rewarder = _rewarder;
        }
        emit Set(_pid, _allocPoint, overwrite ? _rewarder : poolInfo[_pid].rewarder, overwrite);
    }

    // View function to see pending NETTs on frontend.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 pendingNETT,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accNETTPerShare = pool.accNETTPerShare;
        uint256 lpSupply = pool.lpSupply;
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0 && totalAllocPoint > 0) {
            uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
            uint256 nettReward = multiplier.mul(nettPerSec).mul(pool.allocPoint).div(totalAllocPoint);
            accNETTPerShare = accNETTPerShare.add(nettReward.mul(1e12).div(lpSupply));
        }
        pendingNETT = user.amount.mul(accNETTPerShare).div(1e12).sub(user.rewardDebt);

        // If it's a 2xreward farm, we return info about the bonus token
        if (address(pool.rewarder) != address(0)) {
            (bonusTokenAddress, bonusTokenSymbol) = rewarderBonusTokenInfo(_pid);
            pendingBonusToken = pool.rewarder.pendingTokens(_user);
        }
    }

    // Get bonus token info from the rewarder contract for a given pool, if it is a 2xreward farm
    function rewarderBonusTokenInfo(uint256 _pid)
        public
        view
        returns (address bonusTokenAddress, string memory bonusTokenSymbol)
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.rewarder) != address(0)) {
            bonusTokenAddress = address(pool.rewarder.rewardToken());
            bonusTokenSymbol = IERC20(pool.rewarder.rewardToken()).safeSymbol();
        }
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpSupply;
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
        uint256 nettReward = totalAllocPoint > 0 ? multiplier.mul(nettPerSec).mul(pool.allocPoint).div(totalAllocPoint) : 0;
        nett.mint(address(this), nettReward);
        // Mint additional 10% of reward to dev address if it isn't zero address
        if (devAddr != address(0)) {
            nett.mint(devAddr, nettReward.mul(devPercent).div(100));
        }
        pool.accNETTPerShare = pool.accNETTPerShare.add(nettReward.mul(1e12).div(lpSupply));
        pool.lastRewardTimestamp = block.timestamp;
        emit UpdatePool(_pid, pool.lastRewardTimestamp, lpSupply, pool.accNETTPerShare);
    }

    // Deposit LP tokens to NETTFarm for NETT allocation
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            // Harvest NETT
            uint256 pending = user.amount.mul(pool.accNETTPerShare).div(1e12).sub(user.rewardDebt);
            safeNETTTransfer(msg.sender, pending);
            emit Harvest(msg.sender, _pid, pending);
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accNETTPerShare).div(1e12);

        IRewarder rewarder = poolInfo[_pid].rewarder;
        if (address(rewarder) != address(0)) {
            rewarder.onNETTReward(msg.sender, user.amount);
        }
        
        pool.lpSupply = pool.lpSupply.add(_amount);
        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from NETTFarm.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        if (user.amount > 0) {
            // Harvest NETT
            uint256 pending = user.amount.mul(pool.accNETTPerShare).div(1e12).sub(user.rewardDebt);
            safeNETTTransfer(msg.sender, pending);
            emit Harvest(msg.sender, _pid, pending);
        }

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accNETTPerShare).div(1e12);

        IRewarder rewarder = poolInfo[_pid].rewarder;
        if (address(rewarder) != address(0)) {
            rewarder.onNETTReward(msg.sender, user.amount);
        }

        pool.lpSupply = pool.lpSupply.sub(_amount);
        pool.lpToken.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(msg.sender, user.amount);
        pool.lpSupply = pool.lpSupply.sub(user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe NETT transfer function, just in case if rounding error causes pool to not have enough NETTs.
    function safeNETTTransfer(address _to, uint256 _amount) internal {
        uint256 nettBal = nett.balanceOf(address(this));
        if (_amount > nettBal) {
            nett.transfer(_to, nettBal);
        } else {
            nett.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) public {
        require(msg.sender == devAddr, "dev: wut?");
        devAddr = _devAddr;
        emit SetDevAddress(msg.sender, _devAddr);
    }

    function setDevPercent(uint256 _newDevPercent) public onlyOwner {
        require(0 <= _newDevPercent && _newDevPercent <= 100, "setDevPercent: invalid percent value");
        devPercent = _newDevPercent;
    }

    // Pancake has to add hidden dummy pools in order to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _nettPerSec) public onlyOwner {
        massUpdatePools();
        nettPerSec = _nettPerSec;
        emit UpdateEmissionRate(msg.sender, _nettPerSec);
    }
}