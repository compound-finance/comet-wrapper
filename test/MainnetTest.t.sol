// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, ERC20 } from "../src/CometWrapper.sol";
import { CometWrapperTest } from "./CometWrapper.t.sol";
import { CometWrapperInvariantTest } from "./CometWrapperInvariant.t.sol";
import { RewardsTest } from "./Rewards.t.sol";

contract MainnetTest is CometWrapperTest, CometWrapperInvariantTest, RewardsTest {
    string public override NETWORK = "mainnet";
    uint256 public override FORK_BLOCK_NUMBER = 16617900;

    address public override COMET_ADDRESS = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public override REWARD_ADDRESS = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    address public override CONFIGURATOR_ADDRESS = 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3;
    address public override PROXY_ADMIN_ADDRESS = 0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779;
    address public override COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address public override USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public override USDC_HOLDER = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;
    address public override CUSDC_HOLDER = 0x638e9ad05DBd35B1c19dF3a4EAa0642A3B90A2AD;
}
