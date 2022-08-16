
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./VeNETT.sol";

/// @title Vote Escrow NETT Staking
/// @notice Stake NETT to earn veNETT, which you can use to earn higher farm yields and gain
/// voting power. Note that unstaking any amount of NETT will burn all of your existing veNETT.
contract VeNETTStaking is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Info for each user
    /// `balance`: Amount of NETT currently staked by user
    /// `rewardDebt`: The reward debt of the user
    /// `lastClaimTimestamp`: The timestamp of user's last claim or withdraw
    /// `speedUpEndTimestamp`: The timestamp when user stops receiving speed up benefits, or
    /// zero if user is not currently receiving speed up benefits
    struct UserInfo {
        uint256 balance;
        uint256 rewardDebt;
        uint256 lastClaimTimestamp;
        uint256 speedUpEndTimestamp;
        /**
         * @notice We do some fancy math here. Basically, any point in time, the amount of veNETT
         * entitled to a user but is pending to be distributed is:
         *
         *   pendingReward = pendingBaseReward + pendingSpeedUpReward
         *
         *   pendingBaseReward = (user.balance * accVeNETTPerShare) - user.rewardDebt
         *
         *   if user.speedUpEndTimestamp != 0:
         *     speedUpCeilingTimestamp = min(block.timestamp, user.speedUpEndTimestamp)
         *     speedUpSecondsElapsed = speedUpCeilingTimestamp - user.lastClaimTimestamp
         *     pendingSpeedUpReward = speedUpSecondsElapsed * user.balance * speedUpVeNETTPerSharePerSec
         *   else:
         *     pendingSpeedUpReward = 0
         */
    }

    IERC20Upgradeable public nett;
    VeNETT public veNETT;

    // @notice The maximum limit of veNETT user can have as percentage points of staked NETT
    /// For example, if user has `n` NETT staked, they can own a maximum of `n * maxCapPct / 100` veNETT.
    uint256 public maxCapPct;

    /// @notice The upper limit of `maxCapPct`
    uint256 public upperLimitMaxCapPct;

    /// @notice The accrued veNETT per share, scaled to `ACC_VENETT_PER_SHARE_PRECISION`
    uint256 public accVeNETTPerShare;    

    /// @notice Precision of `accVeNETTPerShare`
    uint256 public ACC_VENETT_PER_SHARE_PRECISION;

    /// @notice The last time that the reward variables were updated
    uint256 public lastRewardTimestamp;

    /// @notice veNETT per sec per NETT staked, scaled to `VENETT_PER_SHARE_PER_SEC_PRECISION`
    uint256 public veNETTPerSharePerSec;

    /// @notice Speed up veNETT per sec per NETT staked, scaled to `VENETT_PER_SHARE_PER_SEC_PRECISION`
    uint256 public speedUpVeNETTPerSharePerSec;

    /// @notice The upper limit of `veNETTPerSharePerSec` and `speedUpVeNETTPerSharePerSec`
    uint256 public upperLimitVeNETTPerSharePerSec;

    /// @notice Precision of `veNETTPerSharePerSec`
    uint256 public VENETT_PER_SHARE_PER_SEC_PRECISION;

    /// @notice Percentage of user's current staked NETT user has to deposit in order to start
    /// receiving speed up benefits, in parts per 100.
    /// @dev Specifically, user has to deposit at least `speedUpThreshold/100 * userStakedNETT` NETT.
    /// The only exception is the user will also receive speed up benefits if they are depositing
    /// with zero balance
    uint256 public speedUpThreshold;

    /// @notice The length of time a user receives speed up benefits
    uint256 public speedUpDuration;

    mapping(address => UserInfo) public userInfos;

    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event UpdateMaxCapPct(address indexed user, uint256 maxCapPct);
    event UpdateRewardVars(uint256 lastRewardTimestamp, uint256 accVeNETTPerShare);
    event UpdateSpeedUpThreshold(address indexed user, uint256 speedUpThreshold);
    event UpdateVeNETTPerSharePerSec(address indexed user, uint256 veNETTPerSharePerSec);
    event Withdraw(address indexed user, uint256 withdrawAmount, uint256 burnAmount);

    /// @notice Initialize with needed parameters
    /// @param _nett Address of the NETT token contract
    /// @param _veNETT Address of the veNETT token contract
    /// @param _veNETTPerSharePerSec veNETT per sec per NETT staked, scaled to `VENETT_PER_SHARE_PER_SEC_PRECISION`
    /// @param _speedUpVeNETTPerSharePerSec Similar to `_veNETTPerSharePerSec` but for speed up
    /// @param _speedUpThreshold Percentage of total staked NETT user has to deposit receive speed up
    /// @param _speedUpDuration Length of time a user receives speed up benefits
    /// @param _maxCapPct Maximum limit of veNETT user can have as percentage points of staked NETT
    function initialize(
        IERC20Upgradeable _nett,
        VeNETT _veNETT,
        uint256 _veNETTPerSharePerSec,
        uint256 _speedUpVeNETTPerSharePerSec,
        uint256 _speedUpThreshold,
        uint256 _speedUpDuration,
        uint256 _maxCapPct
    ) public initializer {
        __Ownable_init();

        require(address(_nett) != address(0), "VeNETTStaking: unexpected zero address for _nett");
        require(address(_veNETT) != address(0), "VeNETTStaking: unexpected zero address for _veNETT");

        upperLimitVeNETTPerSharePerSec = 1e36;
        require(
            _veNETTPerSharePerSec <= upperLimitVeNETTPerSharePerSec,
            "VeNETTStaking: expected _veNETTPerSharePerSec to be <= 1e36"
        );
        require(
            _speedUpVeNETTPerSharePerSec <= upperLimitVeNETTPerSharePerSec,
            "VeNETTStaking: expected _speedUpVeNETTPerSharePerSec to be <= 1e36"
        );

        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            "VeNETTStaking: expected _speedUpThreshold to be > 0 and <= 100"
        );

        require(_speedUpDuration <= 365 days, "VeNETTStaking: expected _speedUpDuration to be <= 365 days");

        upperLimitMaxCapPct = 10000000;
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            "VeNETTStaking: expected _maxCapPct to be non-zero and <= 10000000"
        );

        maxCapPct = _maxCapPct;
        speedUpThreshold = _speedUpThreshold;
        speedUpDuration = _speedUpDuration;
        nett = _nett;
        veNETT = _veNETT;
        veNETTPerSharePerSec = _veNETTPerSharePerSec;
        speedUpVeNETTPerSharePerSec = _speedUpVeNETTPerSharePerSec;
        lastRewardTimestamp = block.timestamp;
        ACC_VENETT_PER_SHARE_PRECISION = 1e18;
        VENETT_PER_SHARE_PER_SEC_PRECISION = 1e18;
    }

    /// @notice Set maxCapPct
    /// @param _maxCapPct The new maxCapPct
    function setMaxCapPct(uint256 _maxCapPct) external onlyOwner {
        require(_maxCapPct > maxCapPct, "VeNETTStaking: expected new _maxCapPct to be greater than existing maxCapPct");
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            "VeNETTStaking: expected new _maxCapPct to be non-zero and <= 10000000"
        );
        maxCapPct = _maxCapPct;
        emit UpdateMaxCapPct(_msgSender(), _maxCapPct);
    }

    /// @notice Set veNETTPerSharePerSec
    /// @param _veNETTPerSharePerSec The new veNETTPerSharePerSec
    function setVeNETTPerSharePerSec(uint256 _veNETTPerSharePerSec) external onlyOwner {
        require(
            _veNETTPerSharePerSec <= upperLimitVeNETTPerSharePerSec,
            "VeNETTStaking: expected _veNETTPerSharePerSec to be <= 1e36"
        );
        updateRewardVars();
        veNETTPerSharePerSec = _veNETTPerSharePerSec;
        emit UpdateVeNETTPerSharePerSec(_msgSender(), _veNETTPerSharePerSec);
    }

    /// @notice Set speedUpThreshold
    /// @param _speedUpThreshold The new speedUpThreshold
    function setSpeedUpThreshold(uint256 _speedUpThreshold) external onlyOwner {
        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            "VeNETTStaking: expected _speedUpThreshold to be > 0 and <= 100"
        );
        speedUpThreshold = _speedUpThreshold;
        emit UpdateSpeedUpThreshold(_msgSender(), _speedUpThreshold);
    }

    /// @notice Deposits NETT to start staking for veNETT. Note that any pending veNETT
    /// will also be claimed in the process.
    /// @param _amount The amount of NETT to deposit
    function deposit(uint256 _amount) external {
        require(_amount > 0, "VeNETTStaking: expected deposit amount to be greater than zero");

        updateRewardVars();

        UserInfo storage userInfo = userInfos[_msgSender()];

        if (_getUserHasNonZeroBalance(_msgSender())) {
            // Transfer to the user their pending veNETT before updating their UserInfo
            _claim();

            // We need to update user's `lastClaimTimestamp` to now to prevent
            // passive veNETT accrual if user hit their max cap.
            userInfo.lastClaimTimestamp = block.timestamp;

            uint256 userStakedNETT = userInfo.balance;

            // User is eligible for speed up benefits if `_amount` is at least
            // `speedUpThreshold / 100 * userStakedNETT`
            if (_amount.mul(100) >= speedUpThreshold.mul(userStakedNETT)) {
                userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            }
        } else {
            // If user is depositing with zero balance, they will automatically
            // receive speed up benefits
            userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            userInfo.lastClaimTimestamp = block.timestamp;
        }

        userInfo.balance = userInfo.balance.add(_amount);
        userInfo.rewardDebt = accVeNETTPerShare.mul(userInfo.balance).div(ACC_VENETT_PER_SHARE_PRECISION);

        nett.safeTransferFrom(_msgSender(), address(this), _amount);

        emit Deposit(_msgSender(), _amount);
    }

    /// @notice Withdraw staked NETT. Note that unstaking any amount of NETT means you will
    /// lose all of your current veNETT.
    /// @param _amount The amount of NETT to unstake
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "VeNETTStaking: expected withdraw amount to be greater than zero");

        UserInfo storage userInfo = userInfos[_msgSender()];

        require(
            userInfo.balance >= _amount,
            "VeNETTStaking: cannot withdraw greater amount of NETT than currently staked"
        );
        updateRewardVars();

        // Note that we don't need to claim as the user's veNETT balance will be reset to 0
        userInfo.balance = userInfo.balance.sub(_amount);
        userInfo.rewardDebt = accVeNETTPerShare.mul(userInfo.balance).div(ACC_VENETT_PER_SHARE_PRECISION);
        userInfo.lastClaimTimestamp = block.timestamp;
        userInfo.speedUpEndTimestamp = 0;

        // Burn the user's current veNETT balance
        uint256 userVeNETTBalance = veNETT.balanceOf(_msgSender());
        veNETT.burnFrom(_msgSender(), userVeNETTBalance);

        // Send user their requested amount of staked NETT
        nett.safeTransfer(_msgSender(), _amount);

        emit Withdraw(_msgSender(), _amount, userVeNETTBalance);
    }

    /// @notice Claim any pending veNETT
    function claim() external {
        require(_getUserHasNonZeroBalance(_msgSender()), "VeNETTStaking: cannot claim veNETT when no NETT is staked");
        updateRewardVars();
        _claim();
    }

    /// @notice Get the pending amount of veNETT for a given user
    /// @param _user The user to lookup
    /// @return The number of pending veNETT tokens for `_user`
    function getPendingVeNETT(address _user) public view returns (uint256) {
        if (!_getUserHasNonZeroBalance(_user)) {
            return 0;
        }

        UserInfo memory user = userInfos[_user];

        // Calculate amount of pending base veNETT
        uint256 _accVeNETTPerShare = accVeNETTPerShare;
        uint256 secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        if (secondsElapsed > 0) {
            _accVeNETTPerShare = _accVeNETTPerShare.add(
                secondsElapsed.mul(veNETTPerSharePerSec).mul(ACC_VENETT_PER_SHARE_PRECISION).div(
                    VENETT_PER_SHARE_PER_SEC_PRECISION
                )
            );
        }
        uint256 pendingBaseVeNETT = _accVeNETTPerShare.mul(user.balance).div(ACC_VENETT_PER_SHARE_PRECISION).sub(
            user.rewardDebt
        );

        // Calculate amount of pending speed up veNETT
        uint256 pendingSpeedUpVeNETT;
        if (user.speedUpEndTimestamp != 0) {
            uint256 speedUpCeilingTimestamp = block.timestamp > user.speedUpEndTimestamp
                ? user.speedUpEndTimestamp
                : block.timestamp;
            uint256 speedUpSecondsElapsed = speedUpCeilingTimestamp.sub(user.lastClaimTimestamp);
            uint256 speedUpAccVeNETTPerShare = speedUpSecondsElapsed.mul(speedUpVeNETTPerSharePerSec);
            pendingSpeedUpVeNETT = speedUpAccVeNETTPerShare.mul(user.balance).div(VENETT_PER_SHARE_PER_SEC_PRECISION);
        }

        uint256 pendingVeNETT = pendingBaseVeNETT.add(pendingSpeedUpVeNETT);

        // Get the user's current veNETT balance
        uint256 userVeNETTBalance = veNETT.balanceOf(_user);

        // This is the user's max veNETT cap multiplied by 100
        uint256 scaledUserMaxVeNETTCap = user.balance.mul(maxCapPct);

        if (userVeNETTBalance.mul(100) >= scaledUserMaxVeNETTCap) {
            // User already holds maximum amount of veNETT so there is no pending veNETT
            return 0;
        } else if (userVeNETTBalance.add(pendingVeNETT).mul(100) > scaledUserMaxVeNETTCap) {
            return scaledUserMaxVeNETTCap.sub(userVeNETTBalance.mul(100)).div(100);
        } else {
            return pendingVeNETT;
        }
    }

    /// @notice Update reward variables
    function updateRewardVars() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        if (nett.balanceOf(address(this)) == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        accVeNETTPerShare = accVeNETTPerShare.add(
            secondsElapsed.mul(veNETTPerSharePerSec).mul(ACC_VENETT_PER_SHARE_PRECISION).div(
                VENETT_PER_SHARE_PER_SEC_PRECISION
            )
        );

        lastRewardTimestamp = block.timestamp;

        emit UpdateRewardVars(lastRewardTimestamp, accVeNETTPerShare);
    }

    /// @notice Checks to see if a given user currently has staked NETT
    /// @param _user The user address to check
    /// @return Whether `_user` currently has staked NETT
    function _getUserHasNonZeroBalance(address _user) private view returns (bool) {
        return userInfos[_user].balance > 0;
    }

    /// @dev Helper to claim any pending veNETT
    function _claim() private {
        uint256 veNETTToClaim = getPendingVeNETT(_msgSender());
        
        UserInfo storage userInfo = userInfos[_msgSender()];

        userInfo.rewardDebt = accVeNETTPerShare.mul(userInfo.balance).div(ACC_VENETT_PER_SHARE_PRECISION);

        // If user's speed up period has ended, reset `speedUpEndTimestamp` to 0
        if (userInfo.speedUpEndTimestamp != 0 && block.timestamp >= userInfo.speedUpEndTimestamp) {
            userInfo.speedUpEndTimestamp = 0;
        }

        if (veNETTToClaim > 0) {
            userInfo.lastClaimTimestamp = block.timestamp;

            veNETT.mint(_msgSender(), veNETTToClaim);
            emit Claim(_msgSender(), veNETTToClaim);
        }
    }
}