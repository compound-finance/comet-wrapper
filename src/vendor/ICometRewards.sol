// SPDX-License-Identifier: ISC
pragma solidity 0.8.17;

interface ICometRewards {
    // TODO: how to deal with multiplier?
    struct RewardConfig {
        address token;
        uint64 rescaleFactor;
        bool shouldUpscale;
        // Note: We define new variables after existing variables to keep interface backwards-compatible
        // uint256 multiplier;
        // Note: maybe just document the fact that currently, none of the rewards markets use multipliers.
        // but need to be careful about future markets (unlikely though)
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
