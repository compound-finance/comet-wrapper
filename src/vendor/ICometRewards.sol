// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ICometRewards {
    struct RewardConfig {
        address token;
        uint64 rescaleFactor;
        bool shouldUpscale;
    }

    struct RewardOwed {
        address token;
        uint256 owed;
    }

    function rewardConfig(address) external view returns (RewardConfig memory);

    function claim(address comet, address src, bool shouldAccrue) external;

    function getRewardOwed(address comet, address account) external returns (RewardOwed memory);

    function claimTo(address comet, address src, address to, bool shouldAccrue) external;
}
