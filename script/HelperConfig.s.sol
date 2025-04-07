// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";

abstract contract CodeConstants {
    uint256 public constant MAINNET_ETH_CHAIN_ID = 1;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_HOLESKY_CHAIN_ID = 17000;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address public constant MAINNET_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant SEPOLIA_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant HOLESKY_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address payable public constant TEST_ACCOUNT_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 public constant TEST_ACCOUNT_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPointAddress;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (chainId == ETH_HOLESKY_CHAIN_ID) {
            return getHoleskyConfig();
        } else if (chainId == MAINNET_ETH_CHAIN_ID) {
            return getMainnetConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        console2.log("Deploying mocks...");
        vm.startBroadcast();
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        console2.log("Mocks deployed!");

        return NetworkConfig({entryPointAddress: address(entryPoint)});
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPointAddress: SEPOLIA_ENTRYPOINT_ADDRESS});
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPointAddress: MAINNET_ENTRYPOINT_ADDRESS});
    }

    function getHoleskyConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPointAddress: HOLESKY_ENTRYPOINT_ADDRESS});
    }
}
