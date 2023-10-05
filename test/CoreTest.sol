// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, ERC20 } from "../src/CometWrapper.sol";

abstract contract CoreTest is Test {
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
