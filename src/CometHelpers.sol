// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CometMath} from "./vendor/CometMath.sol";

/**
 * @title Comet Helper Functions
 * @notice Pure helper functions taken from different contracts in Comet
 * @author Compound & gjaldon
 */
contract CometHelpers is CometMath {
    uint64 internal constant FACTOR_SCALE = 1e18;
    uint64 internal constant BASE_INDEX_SCALE = 1e15;
    uint64 internal constant BASE_ACCRUAL_SCALE = 1e6;

    enum Rounding {
        UP,
        DOWN
    }

    /**
     * @dev Multiply a number by a factor
     * https://github.com/compound-finance/comet/blob/main/contracts/Comet.sol#L681-L683
     */
    function mulFactor(uint256 n, uint256 factor) internal pure returns (uint256) {
        return n * factor / FACTOR_SCALE;
    }

    /**
     * @dev The principal amount projected forward by the supply index
     * Note: The returned value can be rounded up or down
     * From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L83-L85
     */
    function presentValueSupply(uint64 baseSupplyIndex_, uint256 principalValue_, Rounding rounding) internal pure returns (uint256) {
        if (rounding == Rounding.DOWN) {
            return principalValue_ * baseSupplyIndex_ / BASE_INDEX_SCALE;
        } else {
            return (principalValue_ * baseSupplyIndex_ + BASE_INDEX_SCALE - 1) / BASE_INDEX_SCALE;
        }
    }

    /**
     * @dev The present value projected backward by the supply index (rounded down)
     * Note: The returned value can be rounded up or down
     * Note: This will overflow (revert) at 2^104/1e18=~20 trillion principal for assets with 18 decimals.
     * From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L109-L111
     */
    function principalValueSupply(uint64 baseSupplyIndex_, uint256 presentValue_, Rounding rounding) internal pure returns (uint104) {
        if (rounding == Rounding.DOWN) {
            return safe104((presentValue_ * BASE_INDEX_SCALE) / baseSupplyIndex_);
        } else {
            return safe104((presentValue_ * BASE_INDEX_SCALE + baseSupplyIndex_ - 1) / baseSupplyIndex_);
        }
    }
}
