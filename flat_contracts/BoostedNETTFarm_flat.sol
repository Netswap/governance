
// File: contracts/libs/Math.sol



pragma solidity ^0.6.12;

// a library for performing various math operations

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
// File: contracts/interfaces/IERC20.sol


pragma solidity 0.6.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
// File: contracts/interfaces/IRewarder.sol



pragma solidity 0.6.12;


interface IRewarder {
    function onNETTReward(address user, uint256 newLpAmount) external;

    function pendingTokens(address user) external view returns (uint256 pending);

    function rewardToken() external view returns (IERC20);
}
// File: contracts/libs/BoringNETTERC20.sol


pragma solidity 0.6.12;


// solhint-disable avoid-low-level-calls

library BoringNETTERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            uint8 i = 0;
            while (i < 32 && data[i] != 0) {
                i++;
            }
            bytes memory bytesArray = new bytes(i);
            for (i = 0; i < 32 && data[i] != 0; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "???";
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}
// File: contracts/interfaces/INETTFarm.sol


pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


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
// File: @openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/Initializable.sol



// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 * 
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 * 
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly { cs := extcodesize(self) }
        return cs == 0;
    }
}

// File: @openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;


/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// File: contracts/BoostedNETTFarm.sol



pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;










/// @notice The (older) NETTFarm contract gives out a constant number of NETT
/// tokens per sec. The idea for this BoostedNETTFarm (BNTF) contract is 
/// therefore to be the owner of a dummy token that is deposited into the NETTFarm (NTF) contract.  
/// The allocation point for this pool on NTF is the total allocation point for all pools on BNTF.
///
/// This NETTFarm also skews how many rewards users receive, it does this by
/// modifying the algorithm that calculates how many tokens are rewarded to
/// depositors. Whereas NETTFarm calculates rewards based on emission rate and
/// total liquidity, this version uses adjusted parameters to this calculation.
///
/// A users `boostedAmount` (liquidity multiplier) is calculated by the actual supplied
/// liquidity multiplied by a boost factor. The boost factor is calculated by the
/// amount of veNETT held by the user over the total veNETT amount held by all pool
/// participants. Total liquidity is the sum of all boosted liquidity.
contract BoostedNETTFarm is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using BoringNETTERC20 for IERC20;
    using SafeMathUpgradeable for uint256;

    /// @notice Info of each BNTF user
    /// `amount` LP token amount the user has provided
    /// `rewardDebt` The amount of NETT entitled to the user
    /// `factor` the users factor, use _getUserFactor
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    /// @notice Info of each BNTF pool
    /// `allocPoint` The amount of allocation points assigned to the pool
    /// Also known as the amount of NETT to distribute per sec
    struct PoolInfo {
        // Address are stored in 160 bits, so we store allocPoint in 96 bits to
        // optimize storage (160 + 96 = 256)
        IERC20 lpToken;
        uint96 allocPoint;
        uint256 accNETTPerShare;
        uint256 accNETTPerFactorPerShare;
        // Address are stored in 160 bits, so we store lastRewardTimestamp in 64 bits and
        // veNETTShareBp in 32 bits to optimize storage (160 + 64 + 32 = 256)
        uint64 lastRewardTimestamp;
        IRewarder rewarder;
        // Share of the reward to distribute to veNETT holders
        uint32 veNETTShareBp;
        // The sum of all veNETT held by users participating in this farm
        // This value is updated when
        // - A user enter/leaves a farm
        // - A user claims veNETT
        // - A user unstakes NETT
        uint256 totalFactor;
        // The total LP supply of the farm
        // This is the sum of all users boosted amounts in the farm. Updated when
        // someone deposits or withdraws.
        // This is used instead of the usual `lpToken.balanceOf(address(this))` for security reasons
        uint256 totalLpSupply;
    }

    /// @notice Address of NTF contract
    INETTFarm public NETTFarm;
    /// @notice Address of NETT contract
    IERC20 public NETT;
    /// @notice Address of veNETT contract
    IERC20 public VENETT;
    /// @notice The index of BNTF master pool in NTF
    uint256 public MASTER_PID;

    /// @notice Info of each BNTF pool
    PoolInfo[] public poolInfo;
    /// @dev Maps an address to a bool to assert that a token isn't added twice
    mapping(IERC20 => bool) private checkPoolDuplicate;

    /// @notice Info of each user that stakes LP tokens
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools
    uint256 public totalAllocPoint;
    uint256 private ACC_TOKEN_PRECISION;

    /// @dev Amount of claimable NETT the user has, this is required as we
    /// need to update rewardDebt after a token operation but we don't
    /// want to send a reward at this point. This amount gets added onto
    /// the pending amount when a user claims
    mapping(uint256 => mapping(address => uint256)) public claimableNETT;

    event Add(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 veNETTShareBp,
        IERC20 indexed lpToken,
        IRewarder indexed rewarder
    );
    event Set(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 veNETTShareBp,
        IRewarder indexed rewarder,
        bool overwrite
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accNETTPerShare,
        uint256 accNETTPerFactorPerShare
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Init(uint256 amount);

    /// @param _NETTFarm The NETTFarm contract address
    /// @param _nett The NETT contract address
    /// @param _veNETT The veNETT contract address
    /// @param _MASTER_PID The pool ID of the dummy token on the base NETTFarm contract
    function initialize(
        INETTFarm _NETTFarm,
        IERC20 _nett,
        IERC20 _veNETT,
        uint256 _MASTER_PID
    ) public initializer {
        __Ownable_init();
        NETTFarm = _NETTFarm;
        NETT = _nett;
        VENETT = _veNETT;
        MASTER_PID = _MASTER_PID;

        ACC_TOKEN_PRECISION = 1e18;
    }

    /// @notice Deposits a dummy token to `NETTFarm` NTF. This is required because NTF
    /// holds the minting rights for NETT.  Any balance of transaction sender in `_dummyToken` is transferred.
    /// The allocation point for the pool on NTF is the total allocation point for all pools that receive
    /// double incentives.
    /// @param _dummyToken The address of the ERC-20 token to deposit into NTF.
    function init(IERC20 _dummyToken) external onlyOwner {
        require(
            _dummyToken.balanceOf(address(NETTFarm)) == 0,
            "BoostedNETTFarm: Already has a balance of dummy token"
        );
        uint256 balance = _dummyToken.balanceOf(_msgSender());
        require(balance != 0, "BoostedNETTFarm: Balance must exceed 0");
        _dummyToken.safeTransferFrom(_msgSender(), address(this), balance);
        _dummyToken.approve(address(NETTFarm), balance);
        NETTFarm.deposit(MASTER_PID, balance);
        emit Init(balance);
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param _allocPoint AP of the new pool.
    /// @param _veNETTShareBp Share of rewards allocated in proportion to user's liquidity
    /// and veNETT balance
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(
        uint96 _allocPoint,
        uint32 _veNETTShareBp,
        IERC20 _lpToken,
        IRewarder _rewarder
    ) external onlyOwner {
        require(!checkPoolDuplicate[_lpToken], "BoostedNETTFarm: LP already added");
        require(_veNETTShareBp <= 10_000, "BoostedNETTFarm: veNETTShareBp needs to be lower than 10000");
        require(poolInfo.length <= 50, "BoostedNETTFarm: Too many pools");
        checkPoolDuplicate[_lpToken] = true;
        // Sanity check to ensure _lpToken is an ERC20 token
        _lpToken.balanceOf(address(this));
        // Sanity check if we add a rewarder
        if (address(_rewarder) != address(0)) {
            _rewarder.onNETTReward(address(0), 0);
        }

        massUpdatePools();

        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                accNETTPerShare: 0,
                accNETTPerFactorPerShare: 0,
                lastRewardTimestamp: uint64(block.timestamp),
                rewarder: _rewarder,
                veNETTShareBp: _veNETTShareBp,
                totalFactor: 0,
                totalLpSupply: 0
            })
        );
        emit Add(poolInfo.length - 1, _allocPoint, _veNETTShareBp, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's NETT allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _allocPoint New AP of the pool
    /// @param _veNETTShareBp Share of rewards allocated in proportion to user's liquidity
    /// and veNETT balance
    /// @param _rewarder Address of the rewarder delegate
    /// @param _overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored
    function set(
        uint256 _pid,
        uint96 _allocPoint,
        uint32 _veNETTShareBp,
        IRewarder _rewarder,
        bool _overwrite
    ) external onlyOwner {
        require(_veNETTShareBp <= 10_000, "BoostedNETTFarm: veNETTShareBp needs to be lower than 10000");
        massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint.add(_allocPoint).sub(pool.allocPoint);
        pool.allocPoint = _allocPoint;
        pool.veNETTShareBp = _veNETTShareBp;
        if (_overwrite) {
            if (address(_rewarder) != address(0)) {
                // Sanity check
                _rewarder.onNETTReward(address(0), 0);
            }
            pool.rewarder = _rewarder;
        }
        
        emit Set(_pid, _allocPoint, _veNETTShareBp, _overwrite ? _rewarder : pool.rewarder, _overwrite);
    }

    /// @notice Deposit LP tokens to BNTF for NETT allocation
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to deposit
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        harvestFromNETTFarm();
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        // Pay a user any pending rewards
        if (user.amount != 0) {
            _harvestNETT(user, pool, _pid);
        }

        uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
        pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
        uint256 receivedAmount = pool.lpToken.balanceOf(address(this)).sub(balanceBefore);

        _updateUserAndPool(user, pool, receivedAmount, true);

        IRewarder _rewarder = pool.rewarder;
        if (address(_rewarder) != address(0)) {
            _rewarder.onNETTReward(_msgSender(), user.amount);
        }
        emit Deposit(_msgSender(), _pid, receivedAmount);
    }

    /// @notice Withdraw LP tokens from BNTF
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        harvestFromNETTFarm();
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "BoostedNETTFarm: withdraw not good");

        if (user.amount != 0) {
            _harvestNETT(user, pool, _pid);
        }

        _updateUserAndPool(user, pool, _amount, false);

        pool.lpToken.safeTransfer(_msgSender(), _amount);
        
        IRewarder _rewarder = pool.rewarder;
        if (address(_rewarder) != address(0)) {
            _rewarder.onNETTReward(_msgSender(), user.amount);
        }
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    /// @notice Updates factor after after a veNETT token operation.
    /// This function needs to be called by the veNETT contract after
    /// every mint / burn.
    /// @param _user The users address we are updating
    /// @param _newVeNETTBalance The new balance of the users veNETT
    function updateFactor(address _user, uint256 _newVeNETTBalance) external {
        require(_msgSender() == address(VENETT), "BoostedNETTFarm: Caller not veNETT");
        uint256 len = poolInfo.length;
        uint256 _ACC_TOKEN_PRECISION = ACC_TOKEN_PRECISION;

        for (uint256 pid; pid < len; ++pid) {
            UserInfo storage user = userInfo[pid][_user];

            // Skip if user doesn't have any deposit in the pool
            uint256 amount = user.amount;
            if (amount == 0) {
                continue;
            }

            PoolInfo storage pool = poolInfo[pid];

            updatePool(pid);
            uint256 oldFactor = user.factor;
            (uint256 accNETTPerShare, uint256 accNETTPerFactorPerShare) = (
                pool.accNETTPerShare,
                pool.accNETTPerFactorPerShare
            );
            uint256 pending = amount
                .mul(accNETTPerShare)
                .add(oldFactor.mul(accNETTPerFactorPerShare))
                .div(_ACC_TOKEN_PRECISION)
                .sub(user.rewardDebt);
            
            // Increase claimableNETT
            claimableNETT[pid][_user] = claimableNETT[pid][_user].add(pending);

            // Update users veNETTBalance
            uint256 newFactor = _getUserFactor(amount, _newVeNETTBalance);
            user.factor = newFactor;
            pool.totalFactor = pool.totalFactor.add(newFactor).sub(oldFactor);

            user.rewardDebt = amount.mul(accNETTPerShare).add(newFactor.mul(accNETTPerFactorPerShare)).div(
                _ACC_TOKEN_PRECISION
            );
        }
    }

    /// @notice Withdraw without caring about rewards (EMERGENCY ONLY)
    /// @param _pid The index of the pool. See `poolInfo`
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        pool.totalFactor = pool.totalFactor.sub(user.factor);
        pool.totalLpSupply = pool.totalLpSupply.sub(user.amount);
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.factor = 0;

        IRewarder _rewarder = pool.rewarder;
        if (address(_rewarder) != address(0)) {
            _rewarder.onNETTReward(_msgSender(), 0);
        }

        // Note: transfer can fail or succeed if `amount` is zero
        pool.lpToken.safeTransfer(_msgSender(), amount);
        emit EmergencyWithdraw(_msgSender(), _pid, amount);
    }

    /// @notice Calculates and returns the `amount` of NETT per second
    /// @return amount The amount of NETT emitted per second
    function nettPerSec() public view returns (uint256 amount) {
        amount = NETTFarm.nettPerSec().mul(NETTFarm.poolInfo(MASTER_PID).allocPoint).div(NETTFarm.totalAllocPoint());
    }

    /// @notice View function to see pending NETT on frontend
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _user Address of user
    /// @return pendingNETT NETT reward for a given user.
    /// @return bonusTokenAddress The address of the bonus reward.
    /// @return bonusTokenSymbol The symbol of the bonus token.
    /// @return pendingBonusToken The amount of bonus rewards pending.
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
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accNETTPerShare = pool.accNETTPerShare;
        uint256 accNETTPerFactorPerShare = pool.accNETTPerFactorPerShare;

        if (block.timestamp > pool.lastRewardTimestamp && pool.totalLpSupply != 0 && pool.allocPoint != 0) {
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 nettReward = secondsElapsed.mul(nettPerSec()).mul(pool.allocPoint).div(totalAllocPoint);
            accNETTPerShare = accNETTPerShare.add(
                nettReward.mul(ACC_TOKEN_PRECISION).mul(10_000 - pool.veNETTShareBp).div(pool.totalLpSupply.mul(10_000))
            );
            if (pool.veNETTShareBp != 0 && pool.totalFactor != 0) {
                accNETTPerFactorPerShare = accNETTPerFactorPerShare.add(
                    nettReward.mul(ACC_TOKEN_PRECISION).mul(pool.veNETTShareBp).div(pool.totalFactor.mul(10_000))
                );
            }
        }

        pendingNETT = (user.amount.mul(accNETTPerShare))
            .add(user.factor.mul(accNETTPerFactorPerShare))
            .div(ACC_TOKEN_PRECISION)
            .add(claimableNETT[_pid][_user])
            .sub(user.rewardDebt);

        // If it's a double reward farm, we return info about the bonus token
        if (address(pool.rewarder) != address(0)) {
            bonusTokenAddress = address(pool.rewarder.rewardToken());
            bonusTokenSymbol = IERC20(bonusTokenAddress).safeSymbol();
            pendingBonusToken = pool.rewarder.pendingTokens(_user);
        }
    }

    /// @notice Returns the number of BNTF pools.
    /// @return pools The amount of pools in this farm
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 len = poolInfo.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(i);
        }
    }

    /// @notice Update reward variables of the given pool
    /// @param _pid The index of the pool. See `poolInfo`
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lastRewardTimestamp = pool.lastRewardTimestamp;
        if (block.timestamp > lastRewardTimestamp) {
            uint256 lpSupply = pool.totalLpSupply;
            uint256 allocPoint = pool.allocPoint;
            // gas opt and prevent div by 0
            if (lpSupply != 0 && allocPoint != 0) {
                uint256 secondsElapsed = block.timestamp - lastRewardTimestamp;
                uint256 veNETTShareBp = pool.veNETTShareBp;
                uint256 totalFactor = pool.totalFactor;

                uint256 nettReward = secondsElapsed.mul(nettPerSec()).mul(allocPoint).div(totalAllocPoint);
                pool.accNETTPerShare = pool.accNETTPerShare.add(
                    nettReward.mul(ACC_TOKEN_PRECISION).mul(10_000 - veNETTShareBp).div(lpSupply.mul(10_000))
                );
                // If veNETTShareBp is 0, then we don't need to update it
                if (veNETTShareBp != 0 && totalFactor != 0) {
                    pool.accNETTPerFactorPerShare = pool.accNETTPerFactorPerShare.add(
                        nettReward.mul(ACC_TOKEN_PRECISION).mul(veNETTShareBp).div(totalFactor.mul(10_000))
                    );
                }
            }
            pool.lastRewardTimestamp = uint64(block.timestamp);emit UpdatePool(
                _pid,
                pool.lastRewardTimestamp,
                lpSupply,
                pool.accNETTPerShare,
                pool.accNETTPerFactorPerShare
            );
        }
    }

    /// @notice Harvests NETT from `NETTFarm` NTF and pool `MASTER_PID` to this BNTF contract
    function harvestFromNETTFarm() public {
        NETTFarm.deposit(MASTER_PID, 0);
    }

    /// @notice Return an user's factor
    /// @param amount The user's amount of liquidity
    /// @param veNETTBalance The user's veNETT balance
    /// @return uint256 The user's factor
    function _getUserFactor(uint256 amount, uint256 veNETTBalance) private pure returns (uint256) {
        return Math.sqrt(amount * veNETTBalance);
    }

    /// @notice Updates user and pool infos
    /// @param _user The user that needs to be updated
    /// @param _pool The pool that needs to be updated
    /// @param _amount The amount that was deposited or withdrawn
    /// @param _isDeposit If the action of the user is a deposit
    function _updateUserAndPool(
        UserInfo storage _user,
        PoolInfo storage _pool,
        uint256 _amount,
        bool _isDeposit
    ) private {
        uint256 oldAmount = _user.amount;
        uint256 newAmount = _isDeposit ? oldAmount.add(_amount) : oldAmount.sub(_amount);

        if (_amount != 0) {
            _user.amount = newAmount;
            _pool.totalLpSupply = _isDeposit ? _pool.totalLpSupply.add(_amount) : _pool.totalLpSupply.sub(_amount);
        }

        uint256 oldFactor = _user.factor;
        uint256 newFactor = _getUserFactor(newAmount, VENETT.balanceOf(_msgSender()));

        if (oldFactor != newFactor) {
            _user.factor = newFactor;
            _pool.totalFactor = _pool.totalFactor.add(newFactor).sub(oldFactor);
        }

        _user.rewardDebt = newAmount.mul(_pool.accNETTPerShare).add(newFactor.mul(_pool.accNETTPerFactorPerShare)).div(
            ACC_TOKEN_PRECISION
        );
    }

    /// @notice Harvests user's pending NETT
    /// @dev WARNING this function doesn't update user's rewardDebt,
    /// it still needs to be updated in order for this contract to work properlly
    /// @param _user The user that will harvest its rewards
    /// @param _pool The pool where the user staked and want to harvest its NETT
    /// @param _pid The pid of that pool
    function _harvestNETT(
        UserInfo storage _user,
        PoolInfo storage _pool,
        uint256 _pid
    ) private {
        uint256 pending = (_user.amount.mul(_pool.accNETTPerShare))
            .add(_user.factor.mul(_pool.accNETTPerFactorPerShare))
            .div(ACC_TOKEN_PRECISION)
            .add(claimableNETT[_pid][_msgSender()])
            .sub(_user.rewardDebt);
        claimableNETT[_pid][_msgSender()] = 0;
        if (pending != 0) {
            NETT.safeTransfer(_msgSender(), pending);
            emit Harvest(_msgSender(), _pid, pending);
        }
    }
}