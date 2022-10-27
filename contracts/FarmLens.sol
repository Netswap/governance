// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./libs/SafeMath.sol";
import "./lens/libs/SafeERC20.sol";
import "./interfaces/INetswapPair.sol";
import "./interfaces/INetswapFactory.sol";

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
            // LP is in 18 decimals, so it's already scaled for JLP
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