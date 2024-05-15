// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import { CometWrapper, CometInterface, ICometRewards, CometHelpers, IERC20 } from "../src/CometWrapper.sol";

// Deploy with:
// $ set -a && source .env && ./script/deploy.sh

// Required ENV vars:
// RPC_URL
// DEPLOYER_PK
// COMET_ADDRESS
// REWARDS_ADDRESS
// PROXY_ADMIN_ADDRESS
// TOKEN_NAME
// TOKEN_SYMBOL

// Optional but suggested ENV vars:
// ETHERSCAN_KEY

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
        proxyAdminAddr = vm.envAddress("PROXY_ADMIN_ADDRESS");
        tokenName = vm.envString("TOKEN_NAME");         // Wrapped Comet WETH || Wrapped Comet USDC
        tokenSymbol = vm.envString("TOKEN_SYMBOL");     // wcWETHv3 || wcUSDCv3
        address deployer = vm.addr(vm.envUint("DEPLOYER_PK"));

        vm.startBroadcast(deployer);

        console.log("=============================================================");
        console.log("Token Name:      ", tokenName);
        console.log("Token Symbol:    ", tokenSymbol);
        console.log("Comet Address:   ", cometAddr);
        console.log("Rewards Address: ", rewardsAddr);
        console.log("Proxy Admin Address: ", proxyAdminAddr);
        console.log("=============================================================");

        CometWrapper cometWrapperImpl =
            new CometWrapper(CometInterface(cometAddr), ICometRewards(rewardsAddr));
        cometWrapperProxy = new TransparentUpgradeableProxy(address(cometWrapperImpl), proxyAdminAddr, "");

        // Wrap in ABI to support easier calls
        CometWrapper cometWrapper = CometWrapper(address(cometWrapperProxy));

        // Initialize the wrapper contract
        cometWrapper.initialize(tokenName, tokenSymbol);

        vm.stopBroadcast();
    }
}
