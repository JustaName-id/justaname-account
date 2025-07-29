// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { JustanAccount } from "../src/JustanAccount.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { Script } from "forge-std/Script.sol";

contract DeployJustanAccount is Script {

    function run() external returns (JustanAccount, HelperConfig.NetworkConfig memory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        JustanAccount account = new JustanAccount{ salt: 0 }(config.entryPointAddress);
        vm.stopBroadcast();

        return (account, config);
    }

}
