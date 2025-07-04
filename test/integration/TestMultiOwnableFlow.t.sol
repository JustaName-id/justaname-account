// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { BaseAccount } from "@account-abstraction/core/BaseAccount.sol";

import "@account-abstraction/core/Helpers.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { Test, Vm, console } from "forge-std/Test.sol";

import { DeployJustaNameAccount } from "../../script/DeployJustaNameAccount.s.sol";
import { CodeConstants, HelperConfig } from "../../script/HelperConfig.s.sol";

import { PreparePackedUserOp } from "../../script/PreparePackedUserOp.s.sol";
import { JustaNameAccount } from "../../src/JustaNameAccount.sol";
import { MultiOwnable } from "../../src/MultiOwnable.sol";

contract TestMultiOwnableFlow is Test, CodeConstants {

    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;
    PreparePackedUserOp public preparePackedUserOp;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, networkConfig) = deployer.run();
        preparePackedUserOp = new PreparePackedUserOp();

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
    }

    function test_ShouldChangeOwnershipCorrectlyWith7702(address owner1, address owner2, address owner3) public {
        vm.assume(owner1 != address(0));
        vm.assume(owner2 != address(0));
        vm.assume(owner3 != address(0));
        vm.assume(owner1 != owner2);
        vm.assume(owner1 != owner3);
        vm.assume(owner2 != owner3);
        vm.assume(owner1 != TEST_ACCOUNT_ADDRESS);
        vm.assume(owner2 != TEST_ACCOUNT_ADDRESS);
        vm.assume(owner3 != TEST_ACCOUNT_ADDRESS);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner1);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner1));

        vm.prank(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner2);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner2));

        vm.prank(owner2);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner3);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 3);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner3));

        vm.prank(owner3);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(2, abi.encode(owner3));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner3));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);

        vm.prank(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(1, abi.encode(owner2));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner2));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 2);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(owner1));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner1));
    }

    function test_ShouldChangeOwnershipCorrectlyWith4337(address newOwner1, address newOwner2) public {
        vm.assume(newOwner1 != address(0));
        vm.assume(newOwner1 != TEST_ACCOUNT_ADDRESS);
        vm.assume(newOwner1 != address(networkConfig.entryPointAddress));
        vm.assume(newOwner2 != address(0));
        vm.assume(newOwner2 != TEST_ACCOUNT_ADDRESS);
        vm.assume(newOwner2 != address(networkConfig.entryPointAddress));
        vm.assume(newOwner1 != newOwner2);

        vm.deal(TEST_ACCOUNT_ADDRESS, 1 ether);

        bytes memory addOwnerData = abi.encodeWithSelector(MultiOwnable.addOwnerAddress.selector, newOwner1);
        bytes memory executeCallData =
            abi.encodeWithSelector(justaNameAccount.execute.selector, TEST_ACCOUNT_ADDRESS, 0, addOwnerData);
        (PackedUserOperation memory userOp,) =
            preparePackedUserOp.generateSignedUserOperation(executeCallData, networkConfig.entryPointAddress);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.prank(newOwner1);
        IEntryPoint(networkConfig.entryPointAddress).handleOps(ops, payable(TEST_ACCOUNT_ADDRESS));

        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(newOwner1));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);

        bytes memory addSecondOwnerData = abi.encodeWithSelector(MultiOwnable.addOwnerAddress.selector, newOwner2);
        bytes memory removeSecondOwnerData =
            abi.encodeWithSelector(MultiOwnable.removeOwnerAtIndex.selector, 1, abi.encode(newOwner2));

        BaseAccount.Call[] memory calls = new BaseAccount.Call[](2);
        calls[0] = BaseAccount.Call({ target: TEST_ACCOUNT_ADDRESS, value: 0, data: addSecondOwnerData });
        calls[1] = BaseAccount.Call({ target: TEST_ACCOUNT_ADDRESS, value: 0, data: removeSecondOwnerData });

        bytes memory executeBatchCallData = abi.encodeWithSelector(justaNameAccount.executeBatch.selector, calls);
        (PackedUserOperation memory batchUserOp,) =
            preparePackedUserOp.generateSignedUserOperation(executeBatchCallData, networkConfig.entryPointAddress);

        PackedUserOperation[] memory batchOps = new PackedUserOperation[](1);
        batchOps[0] = batchUserOp;

        vm.prank(newOwner1);
        IEntryPoint(networkConfig.entryPointAddress).handleOps(batchOps, payable(TEST_ACCOUNT_ADDRESS));

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(newOwner2));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(newOwner1));
    }

}
