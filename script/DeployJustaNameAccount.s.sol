// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Script} from "forge-std/Script.sol";
import {JustaNameAccount} from "../src/JustaNameAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployJustaNameAccount is Script {
    function run() external returns (JustaNameAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        JustaNameAccount account = new JustaNameAccount(config.entryPointAddress);
        vm.stopBroadcast();

        return account;
    }
}
