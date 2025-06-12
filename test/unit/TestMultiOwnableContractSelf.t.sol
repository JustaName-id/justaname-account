// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";

contract TestMultiOwnableContractSelf is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, networkConfig) = deployer.run();

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
    }

    /*//////////////////////////////////////////////////////////////
                       CONTRACT SELF ACCESS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldAllowContractSelfToAddOwnerAddress(address owner) public {
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
    }

    function test_ShouldAllowContractSelfToAddOwnerPublicKey(bytes32 x, bytes32 y) public {
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);

        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(x, y));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
    }

    function test_ShouldAllowContractSelfToRemoveLastOwner(address owner) public {
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(owner));

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);
    }

    function test_ShouldAllowContractSelfToRemoveOwnerAtIndex(address owner1, address owner2) public {
        vm.startPrank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner2);
        vm.stopPrank();

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(owner1));

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner1));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);
    }

    function test_ShouldAllowBothContractSelfAndOwnerAccess(address owner, bytes32 x, bytes32 y) public {
        vm.assume(owner != TEST_ACCOUNT_ADDRESS);
        vm.assume(owner != address(0));

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(owner);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(1, abi.encode(x, y));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner));
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(x, y));
    }
}
