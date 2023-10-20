// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Test } from "forge-std/Test.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, ERC20 } from "../src/CometWrapper.sol";
import { CometWrapperTest } from "./CometWrapper.t.sol";
import { CometWrapperInvariantTest } from "./CometWrapperInvariant.t.sol";
import { EncumberTest } from "./Encumber.t.sol";
import { RewardsTest } from "./Rewards.t.sol";

contract MainnetWETHTest is CometWrapperTest, CometWrapperInvariantTest, EncumberTest, RewardsTest {
    string public override NETWORK = "mainnet";
    uint256 public override FORK_BLOCK_NUMBER = 18285773;

    address public override COMET_ADDRESS = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;
    address public override REWARD_ADDRESS = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    address public override CONFIGURATOR_ADDRESS = 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3;
    address public override PROXY_ADMIN_ADDRESS = 0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779;
    address public override COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address public override UNDERLYING_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public override UNDERLYING_TOKEN_HOLDER = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E; // WETH
    address public override COMET_HOLDER = 0x10D88638Be3c26f3a47d861B8b5641508501035d; // cWETHv3
}
