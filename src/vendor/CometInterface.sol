// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./CometMainInterface.sol";
import "./CometExtInterface.sol";

/**
 * @title Compound's Comet Interface
 * @notice An efficient monolithic money market protocol
 * @author Compound
 */
abstract contract CometInterface is CometMainInterface, CometExtInterface {
    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    function userBasic(address account) external virtual returns (UserBasic memory);

    struct TotalsCollateral {
        uint128 totalSupplyAsset;
        uint128 _reserved;
    }
    function totalsCollateral(address) external virtual returns (TotalsCollateral memory);
}
