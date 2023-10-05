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
    uint256 public decimalScale;

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
        decimalScale = 10 ** usdc.decimals();
    }

    function setUpFuzzTestAssumptions(uint256 amount) public view returns (uint256) {
        string memory underlyingSymbol = usdc.symbol();
        uint256 minBorrow;
        if (isEqual(underlyingSymbol, "USDC") || isEqual(underlyingSymbol, "USDbC")) {
            minBorrow = 100 * decimalScale;
        } else if (isEqual(underlyingSymbol, "WETH")) {
            minBorrow = decimalScale / 10; // 0.1 WETH
        } else {
            revert("Unsupported underlying asset");
        }

        amount = bound(amount, minBorrow, comet.balanceOf(cusdcHolder) - minBorrow);
        return amount;
    }

    function setUpFuzzTestAssumptions(uint256 amount1, uint256 amount2) public view returns (uint256, uint256) {
        string memory underlyingSymbol = usdc.symbol();
        uint256 minBorrow;
        if (isEqual(underlyingSymbol, "USDC") || isEqual(underlyingSymbol, "USDbC")) {
            minBorrow = 100 * decimalScale;
            amount1 = bound(amount1, minBorrow, 2**48);
            amount2 = bound(amount2, minBorrow, 2**48);
        } else if (isEqual(underlyingSymbol, "WETH")) {
            minBorrow = decimalScale / 10; // 0.1 WETH
            amount1 = bound(amount1, minBorrow, 2**88);
            amount2 = bound(amount2, minBorrow, 2**88);
        } else {
            revert("Unsupported underlying asset");
        }

        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder) - minBorrow); // to account for borrowMin
        return (amount1, amount2);
    }

    function isEqual(string memory s1, string memory s2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }
}
