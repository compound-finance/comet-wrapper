// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Test } from "forge-std/Test.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, ERC20 } from "../src/CometWrapper.sol";
import { BySigTest } from "./BySig.t.sol";
import { CometWrapperTest } from "./CometWrapper.t.sol";
import { CometWrapperInvariantTest } from "./CometWrapperInvariant.t.sol";
import { EncumberTest } from "./Encumber.t.sol";
import { RewardsTest } from "./Rewards.t.sol";

contract BaseUSDbCTest is CometWrapperTest, CometWrapperInvariantTest, EncumberTest, RewardsTest, BySigTest {
    string public override NETWORK = "base";
    uint256 public override FORK_BLOCK_NUMBER = 4791144;

    address public override COMET_ADDRESS = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    address public override REWARD_ADDRESS = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public override CONFIGURATOR_ADDRESS = 0x45939657d1CA34A8FA39A924B71D28Fe8431e581;
    address public override PROXY_ADMIN_ADDRESS = 0xbdE8F31D2DdDA895264e27DD990faB3DC87b372d;
    address public override COMP_ADDRESS = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address public override UNDERLYING_TOKEN_ADDRESS = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public override UNDERLYING_TOKEN_HOLDER = 0x4c80E24119CFB836cdF0a6b53dc23F04F7e652CA;
    address public override COMET_HOLDER = 0xBaC3100BEEE79CA34B18fbcD0437bd382Ee5611B;
}
