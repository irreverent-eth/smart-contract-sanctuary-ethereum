// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPoolMaster.sol";

contract ClearpoolLens {
    /// @notice PooLFactory contract
    IPoolFactory public factory;

    /// @notice Number of seconds per year
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    /// @notice Contract constructor
    /// @param factory_ Address of the PoolFactory contract
    constructor(IPoolFactory factory_) {
        factory = factory_;
    }

    /// @notice Function that calculates poolsize-weighted index of pool supply APRs
    /// @return rate Supply rate (APR) index
    function getSupplyRateIndex() external view returns (uint256 rate) {
        address[] memory pools = factory.getPools();
        uint256 totalPoolSize = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            IPoolMaster pool = IPoolMaster(pools[i]);
            uint256 poolSize = pool.poolSize();

            totalPoolSize += poolSize;
            rate += pool.getSupplyRate() * poolSize;
        }
        rate /= totalPoolSize;
    }

    /// @notice Function that calculates poolsize-weighted index of pool borrow APRs
    /// @return rate Borrow rate (APR) index
    function getBorrowRateIndex() external view returns (uint256 rate) {
        address[] memory pools = factory.getPools();
        uint256 totalPoolSize = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            IPoolMaster pool = IPoolMaster(pools[i]);
            uint256 poolSize = pool.poolSize();

            totalPoolSize += poolSize;
            rate += pool.getBorrowRate() * poolSize;
        }
        rate /= totalPoolSize;
    }

    /// @notice Function that calculates total amount of liquidity in all active pools
    /// @return liquidity Total liquidity
    function getTotalLiquidity() external view returns (uint256 liquidity) {
        address[] memory pools = factory.getPools();
        for (uint256 i = 0; i < pools.length; i++) {
            IPoolMaster pool = IPoolMaster(pools[i]);
            liquidity +=
                pool.cash() +
                pool.borrows() -
                pool.insurance() -
                pool.reserves();
        }
    }

    /// @notice Function that calculates total amount of interest accrued in all active pools
    /// @return interest Total interest accrued
    function getTotalInterest() external view returns (uint256 interest) {
        address[] memory pools = factory.getPools();
        for (uint256 i = 0; i < pools.length; i++) {
            interest += IPoolMaster(pools[i]).interest();
        }
    }

    /// @notice Function that calculates total amount of borrows in all active pools
    /// @return borrows Total borrows
    function getTotalBorrows() external view returns (uint256 borrows) {
        address[] memory pools = factory.getPools();
        for (uint256 i = 0; i < pools.length; i++) {
            borrows += IPoolMaster(pools[i]).borrows();
        }
    }

    /// @notice Function that calculates total amount of principal in all active pools
    /// @return principal Total principal
    function getTotalPrincipal() external view returns (uint256 principal) {
        address[] memory pools = factory.getPools();
        for (uint256 i = 0; i < pools.length; i++) {
            principal += IPoolMaster(pools[i]).principal();
        }
    }

    /// @notice Function that calculates total amount of reserves in all active pools
    /// @return reserves Total reserves
    function getTotalReserves() external view returns (uint256 reserves) {
        address[] memory pools = factory.getPools();
        for (uint256 i = 0; i < pools.length; i++) {
            reserves += IPoolMaster(pools[i]).reserves();
        }
    }

    /// @notice Function that calculates CPOOL APR for one pool
    /// @param poolAddress Address of the pool
    /// @param cpoolPrice Price of CPOOL in USD
    /// @return apr Pool's CPOOL APR
    function getPoolCpoolApr(address poolAddress, uint256 cpoolPrice)
        public
        view
        returns (uint256 apr)
    {
        IPoolMaster pool = IPoolMaster(poolAddress);

        uint256 totalSupply = pool.totalSupply();
        uint256 exchangeRate = pool.getCurrentExchangeRate();
        uint256 rewardPerSecond = pool.rewardPerSecond();

        if (totalSupply == 0) {
            return 0; // prevent division by 0
        }

        uint256 poolSupply = totalSupply * exchangeRate;
        uint256 cpoolRewardPerYear = rewardPerSecond * SECONDS_PER_YEAR;
        uint256 usdRewardPerYear = cpoolRewardPerYear * cpoolPrice;

        return usdRewardPerYear / poolSupply;
    }

    /// @notice Function that calculates weighted average of 2 arrays
    /// @param nums array of numbers
    /// @param weights array of weight numbers
    /// @return average and cpoolApr Pools APRs
    function _getWeightedAverage(
        uint256[] memory nums,
        uint256[] memory weights
    ) internal pure returns (uint256 average) {
        uint256 sum = 0;
        uint256 weightSum = 0;

        for (uint256 i = 0; i < weights.length; i++) {
            sum += nums[i] * weights[i];
            weightSum += weights[i];
        }

        return sum / weightSum;
    }

    /// @notice Function that calculates weighted average of pools APRs
    /// @param cpoolPrice Price of CPOOL in USD
    /// @return currencyApr and cpoolApr Pools APRs
    function getAprIndex(uint256 cpoolPrice)
        external
        view
        returns (uint256 currencyApr, uint256 cpoolApr)
    {
        address[] memory pools = factory.getPools();
        uint256 size = pools.length;

        uint256[] memory currencyAprs = new uint256[](size);
        uint256[] memory cpoolAprs = new uint256[](size);
        uint256[] memory poolSizes = new uint256[](size);

        for (uint256 i = 0; i < size; i++) {
            IPoolMaster pool = IPoolMaster(pools[i]);

            poolSizes[i] = pool.poolSize();
            currencyAprs[i] = pool.getSupplyRate();
            cpoolAprs[i] = getPoolCpoolApr(pools[i], cpoolPrice);
        }

        currencyApr = _getWeightedAverage(currencyAprs, poolSizes);
        cpoolApr = _getWeightedAverage(cpoolAprs, poolSizes);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPoolFactory {
    function getPoolSymbol(address currency, address manager)
        external
        view
        returns (string memory);

    function isPool(address pool) external view returns (bool);

    function interestRateModel() external view returns (address);

    function auction() external view returns (address);

    function treasury() external view returns (address);

    function reserveFactor() external view returns (uint256);

    function insuranceFactor() external view returns (uint256);

    function warningUtilization() external view returns (uint256);

    function provisionalDefaultUtilization() external view returns (uint256);

    function warningGracePeriod() external view returns (uint256);

    function maxInactivePeriod() external view returns (uint256);

    function periodToStartAuction() external view returns (uint256);

    function owner() external view returns (address);

    function closePool() external;

    function burnStake() external;

    function getPools() external view returns (address[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPoolMaster {
    function manager() external view returns (address);

    function currency() external view returns (address);

    function borrows() external view returns (uint256);

    function insurance() external view returns (uint256);

    function reserves() external view returns (uint256);

    function getBorrowRate() external view returns (uint256);

    function getSupplyRate() external view returns (uint256);

    function poolSize() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getCurrentExchangeRate() external view returns (uint256);

    function rewardPerSecond() external view returns (uint256);

    function cash() external view returns (uint256);

    function interest() external view returns (uint256);

    function principal() external view returns (uint256);

    enum State {
        Active,
        Warning,
        ProvisionalDefault,
        Default,
        Closed
    }

    function state() external view returns (State);

    function initialize(address manager_, address currency_) external;

    function setRewardPerSecond(uint256 rewardPerSecond_) external;

    function withdrawReward(address account) external returns (uint256);

    function transferReserves() external;

    function processAuctionStart() external;

    function processDebtClaim() external;

    function setManager(address manager_) external;
}