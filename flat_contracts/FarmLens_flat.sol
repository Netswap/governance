
// File: contracts/interfaces/INetswapFactory.sol


pragma solidity 0.6.12;

interface INetswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeRate() external view returns (uint);
    function feeToSetter() external view returns (address);
    function initCodeHash() external view returns (bytes32);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeRate(uint) external;
    function setFeeToSetter(address) external;

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);
}
// File: contracts/interfaces/INetswapPair.sol


pragma solidity 0.6.12;

interface INetswapPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}
// File: contracts/lens/interfaces/IERC20.sol


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
// File: contracts/lens/libs/SafeERC20.sol


pragma solidity 0.6.12;


library SafeERC20 {
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x95d89b41));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x06fdde03));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x313ce567));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: Transfer failed");
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: TransferFrom failed");
    }
}
// File: contracts/libs/SafeMath.sol


pragma solidity ^0.6.12;

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
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// File: contracts/FarmLens.sol


pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;





interface INETTFarm {
    struct PoolInfo {
        IERC20 lpToken; 
        uint256 allocPoint; 
        uint256 lastRewardTimestamp; 
        uint256 accNETTPerShare;
    }

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid) external view returns (INETTFarm.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function nettPerSec() external view returns (uint256);
}

interface IBoostedNETTFarm {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint96 allocPoint;
        uint256 accNETTPerShare;
        uint256 accNETTPerFactorPerShare;
        uint64 lastRewardTimestamp;
        address rewarder;
        uint32 veNETTShareBp;
        uint256 totalFactor;
        uint256 totalLpSupply;
    }

    function userInfo(uint256 _pid, address user) external view returns (UserInfo memory);

    function pendingTokens(uint256 _pid, address user)
        external
        view
        returns (
            uint256,
            address,
            string memory,
            uint256
        );
    
    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function nettPerSec() external view returns (uint256);
}

contract FarmLens {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct FarmInfo {
        uint256 id;
        uint256 allocPoint;
        address lpAddress;
        address token0Address;
        address token1Address;
        string token0Symbol;
        string token1Symbol;
        uint256 reserveUsd;
        uint256 totalSupplyScaled;
        address farmAddress;
        uint256 farmBalanceScaled;
        uint256 farmTotalAlloc;
        uint256 farmNETTPerSec;
    }

    struct BoostedFarmInfo {
        uint256 id;
        uint256 allocPoint;
        address lpAddress;
        address token0Address;
        address token1Address;
        string token0Symbol;
        string token1Symbol;
        uint256 reserveUsd;
        uint256 totalSupplyScaled;
        address farmAddress;
        uint256 farmBalanceScaled;
        uint256 farmTotalAlloc;
        uint256 farmNETTPerSec;
        uint256 baseApr;
        uint256 averageBoostedApr;
        uint256 veNETTShareBp;
        uint256 nettPriceUsd;
        uint256 userLp;
        uint256 userPendingNETT;
        uint256 userBoostedApr;
        uint256 userFactorShare;
    }

    struct AllFarmData {
        uint256 metisPriceUsd;
        uint256 nettPriceUsd;
        uint256 totalAllocNTF;
        uint256 totalAllocBNTF;
        uint256 nettPerSecNTF;
        uint256 nettPerSecBNTF;
        FarmInfo[] NTFInfos;
        BoostedFarmInfo[] BNTFInfos;
    }

    struct GlobalInfo {
        address farm;
        uint256 totalAlloc;
        uint256 nettPerSec;
    }

    /// @dev 365 * 86400, hard coding it for gas optimisation
    uint256 private constant SEC_PER_YEAR = 31536000;
    uint256 private constant BP_PRECISION = 10_000;
    uint256 private constant PRECISION = 1e18;

    address public immutable nett;
    address public immutable metis;
    INetswapPair public immutable metisUsdt;
    INetswapPair public immutable metisUsdc;
    INetswapFactory public immutable netswapFactory;
    INETTFarm public immutable ntf;
    IBoostedNETTFarm public immutable bntf;
    bool private immutable isMetisToken1InMetisUsdt;
    bool private immutable isMetisToken1InMetisUsdc;

    constructor(
        address _nett,
        address _metis,
        INetswapPair _metisUsdt,
        INetswapPair _metisUsdc,
        INetswapFactory _netswapFactory,
        INETTFarm _ntf,
        IBoostedNETTFarm _bntf
    ) public {
        nett = _nett;
        metis = _metis;
        metisUsdt = _metisUsdt;
        metisUsdc = _metisUsdc;
        netswapFactory = _netswapFactory;
        ntf = _ntf;
        bntf = _bntf;

        isMetisToken1InMetisUsdt = _metisUsdt.token1() == _metis;
        isMetisToken1InMetisUsdc = _metisUsdc.token1() == _metis;
    }

    /// @notice Returns the price of metis in Usd
    /// @return uint256 the metis price, scaled to 18 decimals
    function getMetisPrice() external view returns (uint256) {
        return _getMetisPrice();
    }

    /// @notice Returns the derived price of token, it needs to be paired with metis
    /// @param token The address of the token
    /// @return uint256 the token derived price, scaled to 18 decimals
    function getDerivedMetisPriceOfToken(address token) external view returns (uint256) {
        return _getDerivedMetisPriceOfToken(token);
    }

    /// @notice Returns the Usd price of token, it needs to be paired with metis
    /// @param token The address of the token
    /// @return uint256 the Usd price of token, scaled to 18 decimals
    function getTokenPrice(address token) external view returns (uint256) {
        return _getDerivedMetisPriceOfToken(token).mul(_getMetisPrice()) / 1e18;
    }

    /// @notice Returns the farm pairs data for NETTFarm
    /// @param _ntf The address of the NETTFarm
    /// @param whitelistedPids Array of all ids of pools that are whitelisted and valid to have their farm data returned
    /// @return FarmInfo The information of all the whitelisted farms of NETTFarm
    function getNETTFarmInfos(INETTFarm _ntf, uint256[] calldata whitelistedPids) 
        external
        view
        returns (FarmInfo[] memory)
    {
        require(_ntf == ntf, "FarmLens: only for NETTFarm");

        uint256 metisPrice = _getMetisPrice();
        return _getNETTFarmInfos(_ntf, metisPrice, whitelistedPids);
    }

    /// @notice Returns the farm pairs data for BoostedNETTFarm
    /// @param _bntf The address of the BoostedNETTFarm
    /// @param user The address of the user, if address(0), returns global info
    /// @param whitelistedPids Array of all ids of pools that are whitelisted and valid to have their farm data returned
    /// @return BoostedFarmInfo The information of all the whitelisted farms of BoostedNETTFarm
    function getBoostedFarmInfos(
        IBoostedNETTFarm _bntf,
        address user,
        uint256[] calldata whitelistedPids
    ) external view returns (BoostedFarmInfo[] memory) {
        require(_bntf == bntf, "FarmLens: Only for BoostedNETTFarm");

        uint256 metisPrice = _getMetisPrice();
        uint256 nettPrice = _getDerivedMetisPriceOfToken(nett).mul(metisPrice) / PRECISION;
        return _getBoostedFarmInfos(metisPrice, nettPrice, user, whitelistedPids);
    }

    /// @notice Get all data needed for useFarms hook.
    /// @param whitelistedPidsNTF Array of all ids of pools that are whitelisted in NETTFarm
    /// @param whitelistedPidsBNTF Array of all ids of pools that are whitelisted in BoostedNETTFarm
    /// @param user The address of the user, if address(0), returns global info
    /// @return AllFarmData The information of all the whitelisted farms of NETTFarm and BoostedNETTFarm
    function getAllFarmData(
        uint256[] calldata whitelistedPidsNTF,
        uint256[] calldata whitelistedPidsBNTF,
        address user
    ) external view returns (AllFarmData memory) {
        AllFarmData memory allFarmData;

        uint256 metisPrice = _getMetisPrice();
        uint256 nettPrice = _getDerivedMetisPriceOfToken(nett).mul(metisPrice) / PRECISION;

        allFarmData.metisPriceUsd = metisPrice;
        allFarmData.nettPriceUsd = nettPrice;

        allFarmData.totalAllocNTF = ntf.totalAllocPoint();
        allFarmData.nettPerSecNTF = ntf.nettPerSec();

        allFarmData.totalAllocBNTF = bntf.totalAllocPoint();
        allFarmData.nettPerSecBNTF = bntf.nettPerSec();

        allFarmData.NTFInfos = _getNETTFarmInfos(ntf, metisPrice, whitelistedPidsNTF);
        allFarmData.BNTFInfos = _getBoostedFarmInfos(metisPrice, nettPrice, user, whitelistedPidsBNTF);

        return allFarmData;
    }

    /// @notice Returns the price of metis in Usd internally
    /// @return uint256 the metis price, scaled to 18 decimals
    function _getMetisPrice() private view returns (uint256) {
        return
            _getDerivedTokenPriceOfPair(metisUsdt, isMetisToken1InMetisUsdt)
                .add(_getDerivedTokenPriceOfPair(metisUsdc, isMetisToken1InMetisUsdc)) / 2;
    }

    /// @notice Returns the derived price of token in the other token
    /// @param pair The address of the pair
    /// @param derivedtoken0 If price should be derived from token0 if true, or token1 if false
    /// @return uint256 the derived price, scaled to 18 decimals
    function _getDerivedTokenPriceOfPair(INetswapPair pair, bool derivedtoken0) private view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 decimals0 = IERC20(pair.token0()).safeDecimals();
        uint256 decimals1 = IERC20(pair.token1()).safeDecimals();

        if (derivedtoken0) {
            return _scaleTo(reserve0, decimals1.add(18).sub(decimals0)).div(reserve1);
        } else {
            return _scaleTo(reserve1, decimals0.add(18).sub(decimals1)).div(reserve0);
        }
    }

    /// @notice Returns the derived price of token, it needs to be paired with metis
    /// @param token The address of the token
    /// @return uint256 the token derived price, scaled to 18 decimals
    function _getDerivedMetisPriceOfToken(address token) private view returns (uint256) {
        if (token == metis) {
            return PRECISION;
        }
        INetswapPair pair = INetswapPair(netswapFactory.getPair(token, metis));
        if (address(pair) == address(0)) {
            return 0;
        }
        // instead of testing metis == pair.token0(), we do the opposite to save gas
        return _getDerivedTokenPriceOfPair(pair, token == pair.token1());
    }

    /// @notice Returns the amount scaled to decimals
    /// @param amount The amount
    /// @param decimals The decimals to scale `amount`
    /// @return uint256 The amount scaled to decimals
    function _scaleTo(uint256 amount, uint256 decimals) private pure returns (uint256) {
        if (decimals == 0) return amount;
        return amount.mul(10**decimals);
    }

    /// @notice Returns the derived metis liquidity, at least one of the token needs to be paired with metis
    /// @param pair The address of the pair
    /// @return uint256 the derived price of pair's liquidity, scaled to 18 decimals
    function _getDerivedMetisLiquidityOfPair(INetswapPair pair) private view returns (uint256) {
        address _metis = metis;
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        IERC20 token0 = IERC20(pair.token0());
        IERC20 token1 = IERC20(pair.token1());
        uint256 decimals0 = token0.safeDecimals();
        uint256 decimals1 = token1.safeDecimals();

        reserve0 = _scaleTo(reserve0, uint256(18).sub(decimals0));
        reserve1 = _scaleTo(reserve1, uint256(18).sub(decimals1));

        uint256 token0DerivedMetisPrice;
        uint256 token1DerivedMetisPrice;
        if (address(token0) == _metis) {
            token0DerivedMetisPrice = PRECISION;
            token1DerivedMetisPrice = _getDerivedTokenPriceOfPair(pair, true);
        } else if (address(token1) == _metis) {
            token0DerivedMetisPrice = _getDerivedTokenPriceOfPair(pair, false);
            token1DerivedMetisPrice = PRECISION;
        } else {
            token0DerivedMetisPrice = _getDerivedMetisPriceOfToken(address(token0));
            token1DerivedMetisPrice = _getDerivedMetisPriceOfToken(address(token1));
            // If one token isn't paired with metis, then we hope that the second one is.
            // E.g, TOKEN/m.USDC, token might not be paired with metis, but m.USDC is.
            // If both aren't paired with metis, return 0
            if (token0DerivedMetisPrice == 0) return reserve1.mul(token0DerivedMetisPrice).mul(2) / PRECISION;
            if (token1DerivedMetisPrice == 0) return reserve0.mul(token1DerivedMetisPrice).mul(2) / PRECISION;
        }
        return reserve0.mul(token0DerivedMetisPrice).add(reserve1.mul(token1DerivedMetisPrice)) / PRECISION;
    }

    /// @notice Private function to return the farm pairs data for a given NETTFarm
    /// @param _ntf The address of the NETTFarm
    /// @param metisPrice The metis price as a parameter to save gas
    /// @param whitelistedPids Array of all ids of pools that are whitelisted and valid to have their farm data returned
    /// @return FarmInfo The information of all the whitelisted farms of NETTFarm
    function _getNETTFarmInfos(
        INETTFarm _ntf,
        uint256 metisPrice,
        uint256[] calldata whitelistedPids
    ) private view returns (FarmInfo[] memory) {
        uint256 whitelistLength = whitelistedPids.length;
        FarmInfo[] memory farmInfos = new FarmInfo[](whitelistLength);

        uint256 ntfTotalAlloc = _ntf.totalAllocPoint();
        uint256 ntfNETTPerSec = _ntf.nettPerSec();

        for (uint256 i; i < whitelistLength; i++) {
            uint256 pid = whitelistedPids[i];
            INETTFarm.PoolInfo memory pool = _ntf.poolInfo(pid);

            farmInfos[i] = _getNETTFarmInfo(
                _ntf,
                metisPrice,
                pid,
                INetswapPair(address(pool.lpToken)),
                pool.allocPoint,
                ntfTotalAlloc,
                ntfNETTPerSec
            );
        }

        return farmInfos;
    }

    /// @notice Helper function to return the farm info of a given pool
    /// @param _ntf The address of the NETTFarm
    /// @param metisPrice The metis price as a parameter to save gas
    /// @param pid The pid of the pool
    /// @param lpToken The lpToken of the pool
    /// @param allocPoint The allocPoint of the pool
    /// @return FarmInfo The information of all the whitelisted farms of NETTFarm
    function _getNETTFarmInfo(
        INETTFarm _ntf,
        uint256 metisPrice,
        uint256 pid,
        INetswapPair lpToken,
        uint256 allocPoint,
        uint256 totalAllocPoint,
        uint256 ntfNETTPerSec
    ) private view returns (FarmInfo memory) {
        uint256 decimals = lpToken.decimals();
        uint256 totalSupplyScaled = _scaleTo(lpToken.totalSupply(), 18 - decimals);
        uint256 ntfBalanceScaled = _scaleTo(lpToken.balanceOf(address(_ntf)), 18 - decimals);
        uint256 reserveUsd = _getDerivedMetisLiquidityOfPair(lpToken).mul(metisPrice) / PRECISION;
        IERC20 token0 = IERC20(lpToken.token0());
        IERC20 token1 = IERC20(lpToken.token1());

        return
            FarmInfo({
                id: pid,
                allocPoint: allocPoint,
                lpAddress: address(lpToken),
                token0Address: address(token0),
                token1Address: address(token1),
                token0Symbol: token0.safeSymbol(),
                token1Symbol: token1.safeSymbol(),
                reserveUsd: reserveUsd,
                totalSupplyScaled: totalSupplyScaled,
                farmBalanceScaled: ntfBalanceScaled,
                farmAddress: address(_ntf),
                farmTotalAlloc: totalAllocPoint,
                farmNETTPerSec: ntfNETTPerSec
            });
    }

    /// @notice Private function to return the farm pairs data for BoostedNETTFarm
    /// @param metisPrice The metis price as a parameter to save gas
    /// @param nettPrice The nett price as a parameter to save gas
    /// @param user The address of the user, if address(0), returns global info
    /// @param whitelistedPids Array of all ids of pools that are whitelisted and valid to have their farm data returned
    /// @return BoostedFarmInfo The information of all the whitelisted farms of BoostedNETTFarm
    function _getBoostedFarmInfos(
        uint256 metisPrice,
        uint256 nettPrice,
        address user,
        uint256[] calldata whitelistedPids
    ) private view returns (BoostedFarmInfo[] memory) {
        GlobalInfo memory globalInfo = GlobalInfo(address(bntf), bntf.totalAllocPoint(), bntf.nettPerSec());

        uint256 whitelistLength = whitelistedPids.length;
        BoostedFarmInfo[] memory farmInfos = new BoostedFarmInfo[](whitelistLength);

        for (uint256 i; i < whitelistLength; i++) {
            uint256 pid = whitelistedPids[i];
            IBoostedNETTFarm.PoolInfo memory pool = IBoostedNETTFarm(globalInfo.farm).poolInfo(pid);
            IBoostedNETTFarm.UserInfo memory userInfo;
            userInfo = IBoostedNETTFarm(globalInfo.farm).userInfo(pid, user);

            farmInfos[i].id = pid;
            farmInfos[i].farmAddress = globalInfo.farm;
            farmInfos[i].farmTotalAlloc = globalInfo.totalAlloc;
            farmInfos[i].farmNETTPerSec = globalInfo.nettPerSec;
            farmInfos[i].nettPriceUsd = nettPrice;
            _getBoostedFarmInfo(
                metisPrice,
                globalInfo.nettPerSec.mul(nettPrice) / PRECISION,
                user,
                farmInfos[i],
                pool,
                userInfo
            );
        }

        return farmInfos;
    }

    /// @notice Helper function to return the farm info of a given pool of BoostedNETTFarm
    /// @param metisPrice The metis price as a parameter to save gas
    /// @param UsdPerSec The Usd per sec emitted to BoostedNETTFarm
    /// @param userAddress The address of the user
    /// @param farmInfo The farmInfo of that pool
    /// @param user The user information
    function _getBoostedFarmInfo(
        uint256 metisPrice,
        uint256 UsdPerSec,
        address userAddress,
        BoostedFarmInfo memory farmInfo,
        IBoostedNETTFarm.PoolInfo memory pool,
        IBoostedNETTFarm.UserInfo memory user
    ) private view {
        {
            INetswapPair lpToken = INetswapPair(address(pool.lpToken));
            IERC20 token0 = IERC20(lpToken.token0());
            IERC20 token1 = IERC20(lpToken.token1());

            farmInfo.allocPoint = pool.allocPoint;
            farmInfo.lpAddress = address(lpToken);
            farmInfo.token0Address = address(token0);
            farmInfo.token1Address = address(token1);
            farmInfo.token0Symbol = token0.safeSymbol();
            farmInfo.token1Symbol = token1.safeSymbol();
            farmInfo.reserveUsd = _getDerivedMetisLiquidityOfPair(lpToken).mul(metisPrice) / PRECISION;
            // LP is in 18 decimals, so it's already scaled for NLP
            farmInfo.totalSupplyScaled = lpToken.totalSupply();
            farmInfo.farmBalanceScaled = pool.totalLpSupply;
            farmInfo.userLp = user.amount;
            farmInfo.veNETTShareBp = pool.veNETTShareBp;
            (farmInfo.userPendingNETT, , , ) = bntf.pendingTokens(farmInfo.id, userAddress);
        }

        if (
            pool.totalLpSupply != 0 &&
            farmInfo.totalSupplyScaled != 0 &&
            farmInfo.farmTotalAlloc != 0 &&
            farmInfo.reserveUsd != 0
        ) {
            uint256 poolUsdPerYear = UsdPerSec.mul(pool.allocPoint).mul(SEC_PER_YEAR) / farmInfo.farmTotalAlloc;

            uint256 poolReserveUsd = farmInfo.reserveUsd.mul(farmInfo.farmBalanceScaled) / farmInfo.totalSupplyScaled;

            if (poolReserveUsd == 0) return;

            farmInfo.baseApr =
                poolUsdPerYear.mul(BP_PRECISION - pool.veNETTShareBp).mul(PRECISION) /
                poolReserveUsd /
                BP_PRECISION;

            if (pool.totalFactor != 0) {
                farmInfo.averageBoostedApr =
                    poolUsdPerYear.mul(pool.veNETTShareBp).mul(PRECISION) /
                    poolReserveUsd /
                    BP_PRECISION;

                if (user.amount != 0 && user.factor != 0) {
                    uint256 userLpUsd = user.amount.mul(farmInfo.reserveUsd) / pool.totalLpSupply;

                    farmInfo.userBoostedApr =
                        poolUsdPerYear.mul(pool.veNETTShareBp).mul(user.factor).div(pool.totalFactor).mul(PRECISION) /
                        userLpUsd /
                        BP_PRECISION;

                    farmInfo.userFactorShare = user.factor.mul(PRECISION) / pool.totalFactor;
                }
            }
        }

    }
}