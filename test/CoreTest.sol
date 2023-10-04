// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, ERC20 } from "../src/CometWrapper.sol";

abstract contract CoreTest is Test {
    // "comet": "0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf",
    // "configurator": "0x45939657d1CA34A8FA39A924B71D28Fe8431e581",
    // "rewards": "0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1",
    // "bridgeReceiver": "0x18281dfC4d00905DA1aaA6731414EABa843c468A",
    // "l2CrossDomainMessenger": "0x4200000000000000000000000000000000000007",
    // "l2StandardBridge": "0x4200000000000000000000000000000000000010",
    // "bulker": "0x78D0677032A35c63D142a48A2037048871212a8C"
    // address constant cometAddress = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    // address constant rewardAddress = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    // address constant compAddress = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    // address constant usdcHolder = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;
    // address constant usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address constant cusdcHolder = 0xBaC3100BEEE79CA34B18fbcD0437bd382Ee5611B;
    // address cometAddress;
    // address rewardAddress;
    // address compAddress;
    // address usdcHolder;
    // address usdcAddress;
    // address cusdcHolder;

    function NETWORK() external virtual returns (string calldata);
    function FORK_BLOCK_NUMBER() external virtual returns (uint256);

    function COMET_ADDRESS() external virtual returns (address);
    function REWARD_ADDRESS() external virtual returns (address);
    function CONFIGURATOR_ADDRESS() external virtual returns (address);
    function PROXY_ADMIN_ADDRESS() external virtual returns (address);
    function COMP_ADDRESS() external virtual returns (address);
    function USDC_ADDRESS() external virtual returns (address);
    function USDC_HOLDER() external virtual returns (address);
    function CUSDC_HOLDER() external virtual returns (address);

    address public cometAddress;
    address public rewardAddress;
    address public configuratorAddress;
    address public proxyAdminAddress;
    address public compAddress;
    address public usdcHolder;
    address public usdcAddress;
    address public cusdcHolder;

    CometWrapper public cometWrapper;
    CometInterface public comet;
    ICometRewards public cometRewards;
    ERC20 public usdc;
    ERC20 public comp;
    address public wrapperAddress;

    address alice = address(0xABCD);
    address bob = address(0xDCBA);

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        // vm.createSelectFork(vm.rpcUrl("base"), 4791144);
        vm.createSelectFork(vm.rpcUrl(this.NETWORK()), this.FORK_BLOCK_NUMBER());

        cometAddress = this.COMET_ADDRESS();
        rewardAddress = this.REWARD_ADDRESS();
        configuratorAddress = this.CONFIGURATOR_ADDRESS();
        proxyAdminAddress = this.PROXY_ADMIN_ADDRESS();
        compAddress = this.COMP_ADDRESS();
        usdcAddress = this.USDC_ADDRESS();
        usdcHolder = this.USDC_HOLDER();
        cusdcHolder = this.CUSDC_HOLDER();

        usdc = ERC20(this.usdcAddress());
        comp = ERC20(this.compAddress());
        comet = CometInterface(this.cometAddress());
        cometRewards = ICometRewards(this.rewardAddress());
        cometWrapper =
            new CometWrapper(ERC20(this.cometAddress()), ICometRewards(this.rewardAddress()), "Wrapped Comet USDC", "WcUSDCv3");
        wrapperAddress = address(cometWrapper);
    }
}
