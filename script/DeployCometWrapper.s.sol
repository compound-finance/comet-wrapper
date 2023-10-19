// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, IERC20 } from "../src/CometWrapper.sol";

// Deploy with:
// $ source .env
// $ forge script script/DeployCometWrapper.s.sol --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv -t --sender address
// Change COMET_ADDRESS and REWARDS_ADDRESS to use the correct addresses for their corresponding CHAIN. Use the correct
// RPC too for the CHAIN you wish to deploy to.
// Required ENV Vars:
// COMET_ADDRESS
// REWARDS_ADDRESS
// TOKEN_NAME
// TOKEN_SYMBOL

contract DeployCometWrapper is Script {
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy cometWrapperProxy;
    address internal cometAddr;
    address internal rewardsAddr;
    address internal proxyAdminAddr;
    string internal tokenName;
    string internal tokenSymbol;

    function run() public {
        cometAddr = vm.envAddress("COMET_ADDRESS");
        rewardsAddr = vm.envAddress("REWARDS_ADDRESS");
        proxyAdminAddr = vm.envAddress("PROXY_ADMIN");
        tokenName = vm.envString("TOKEN_NAME");         // Wrapped Comet WETH || Wrapped Comet USDC
        tokenSymbol = vm.envString("TOKEN_SYMBOL");     // WcWETHv3 || WcUSDCv3

        vm.startBroadcast();

        console.log("=============================================================");
        console.log("Token Name:      ", tokenName);
        console.log("Token Symbol:    ", tokenSymbol);
        console.log("Comet Address:   ", cometAddr);
        console.log("Rewards Address: ", rewardsAddr);
        console.log("Proxy Admin Address: ", proxyAdminAddr);
        console.log("=============================================================");

        CometWrapper cometWrapperImpl =
            new CometWrapper(IERC20(cometAddr), ICometRewards(rewardsAddr));
        cometWrapperProxy = new TransparentUpgradeableProxy(address(cometWrapperImpl), proxyAdminAddr, "");

        // Wrap in ABI to support easier calls
        CometWrapper cometWrapper = CometWrapper(address(cometWrapperProxy));

        // Initialize the wrapper contract
        cometWrapper.initialize(tokenName, tokenSymbol);

        vm.stopBroadcast();
    }
}
