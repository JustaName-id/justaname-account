// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { JustaNameAccount } from "../src/JustaNameAccount.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { Script } from "forge-std/Script.sol";

contract DeployJustaNameAccount is Script {

    function run() external returns (JustaNameAccount, HelperConfig.NetworkConfig memory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        JustaNameAccount account = new JustaNameAccount{ salt: 0 }(config.entryPointAddress);
        vm.stopBroadcast();

        return (account, config);
    }

}
