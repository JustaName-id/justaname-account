// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BaseAccount} from "@account-abstraction/core/BaseAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import "@account-abstraction/core/Helpers.sol";

import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";
import {MultiOwnable} from "../../src/MultiOwnable.sol";
import {PreparePackedUserOp} from "../../script/PreparePackedUserOp.s.sol";

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

    function test_ShouldChangeOwnershipCorrectly(
        address owner1,
        address owner2,
        address owner3,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        bytes32 pubKeyX2,
        bytes32 pubKeyY2
    ) public {
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
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(pubKeyX, pubKeyY);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(pubKeyX, pubKeyY));

        vm.prank(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner2);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 3);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner2));

        vm.prank(owner2);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(pubKeyX2, pubKeyY2);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 4);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(pubKeyX2, pubKeyY2));

        vm.prank(owner2);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner3);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 5);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner3));

        vm.prank(owner3);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(4, abi.encode(owner3));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 4);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner3));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);

        vm.prank(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(3, abi.encode(pubKeyX2, pubKeyY2));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 3);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(pubKeyX2, pubKeyY2));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 2);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(2, abi.encode(owner2));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner2));

        vm.prank(owner1);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(1, abi.encode(pubKeyX, pubKeyY));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(pubKeyX, pubKeyY));

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(owner1));

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner1));
    }

    // function test_ShouldAddOwnerVia4337(address newOwner) public {
    //     vm.assume(newOwner != address(0));
    //     vm.assume(newOwner != TEST_ACCOUNT_ADDRESS);

    //     vm.deal(TEST_ACCOUNT_ADDRESS, 1 ether);

    //     bytes memory functionData = abi.encodeWithSelector(
    //         bytes4(keccak256("addOwnerAddress(address)")),
    //         newOwner
    //     );

    //     (PackedUserOperation memory userOp,) = preparePackedUserOp.generateSignedUserOperation(
    //         functionData,
    //         networkConfig.entryPointAddress
    //     );

    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = userOp;

    //     try IEntryPoint(networkConfig.entryPointAddress).handleOps(ops, payable(TEST_ACCOUNT_ADDRESS)) {
    //         console.log("UserOperation executed successfully");
    //     } catch Error(string memory reason) {
    //         console.log("UserOperation failed:", reason);
    //         revert(reason);
    //     }

    //     assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(newOwner));
    //     assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
    // }
}
