// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { Test, Vm, console } from "forge-std/Test.sol";

import { DeployJustanAccount } from "../../script/DeployJustanAccount.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { CodeConstants } from "../../script/HelperConfig.s.sol";
import { JustanAccount } from "../../src/JustanAccount.sol";
import { MultiOwnable } from "../../src/MultiOwnable.sol";

contract TestMultiOwnableWithOwners is Test, CodeConstants {

    JustanAccount public justanAccount;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;

    address public INITIAL_OWNER;
    uint256 public INITIAL_OWNER_PK;

    function setUp() public {
        DeployJustanAccount deployer = new DeployJustanAccount();
        (justanAccount, networkConfig) = deployer.run();

        (INITIAL_OWNER, INITIAL_OWNER_PK) = makeAddrAndKey("INITIAL_OWNER");

        vm.signAndAttachDelegation(address(justanAccount), TEST_ACCOUNT_PRIVATE_KEY);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(INITIAL_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIAL OWNERSHIP CHECK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnTrueForOwnerAddress() public view {
        assertTrue(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
    }

    function test_ShouldReturnFalseForNonOwnerAddress(address nonOwner) public view {
        vm.assume(nonOwner != INITIAL_OWNER);

        assertFalse(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(nonOwner));
    }

    function test_ShouldReturnTrueForOwnerBytes() public view {
        assertTrue(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerBytes(abi.encode(INITIAL_OWNER)));
    }

    function test_ShouldReturnFalseForNonOwnerBytes(address nonOwner) public view {
        vm.assume(nonOwner != INITIAL_OWNER);

        assertFalse(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerBytes(abi.encode(nonOwner)));
    }

    function test_ShouldReturnCorrectOwnerAtIndex() public view {
        bytes memory ownerBytes = JustanAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(0);
        assertEq(ownerBytes, abi.encode(INITIAL_OWNER));
    }

    function test_ShouldReturnEmptyBytesForEmptyIndex() public view {
        bytes memory ownerBytes = JustanAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(5);
        assertEq(ownerBytes.length, 0);
    }

    function test_ShouldReturnCorrectNextOwnerIndex() public view {
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).nextOwnerIndex(), 1);
    }

    function test_ShouldReturnCorrectOwnerCount() public view {
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
    }

    function test_ShouldReturnZeroRemovedOwnersCount() public view {
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD OWNER ADDRESS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldAddOwnerAddressCorrectly(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.expectEmit(true, false, false, false, TEST_ACCOUNT_ADDRESS);
        emit MultiOwnable.AddOwner(1, abi.encode(owner));

        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).nextOwnerIndex(), 2);
        assertTrue(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner));
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(1), abi.encode(owner));
    }

    function test_ThrowErrorIfAddingDuplicateOwnerAddress() public {
        vm.prank(INITIAL_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(MultiOwnable.MultiOwnable_AlreadyOwner.selector, abi.encode(INITIAL_OWNER))
        );
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(INITIAL_OWNER);
    }

    function test_ThrowErrorIfNonOwnerAddsOwnerAddress(address nonOwner) public {
        vm.assume(nonOwner != INITIAL_OWNER);
        vm.assume(nonOwner != address(0));
        vm.assume(nonOwner != TEST_ACCOUNT_ADDRESS);
        vm.assume(nonOwner != address(networkConfig.entryPointAddress));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.MultiOwnable_Unauthorized.selector));
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(nonOwner);
    }

    /*//////////////////////////////////////////////////////////////
                      REMOVE OWNER AT INDEX TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldRemoveOwnerAtIndexCorrectly(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.expectEmit(true, false, false, false, TEST_ACCOUNT_ADDRESS);
        emit MultiOwnable.RemoveOwner(0, abi.encode(INITIAL_OWNER));

        vm.prank(owner);
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));

        assertFalse(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);
    }

    function test_ThrowErrorIfRemovingLastOwner() public {
        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.MultiOwnable_LastOwner.selector));
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));
    }

    function test_ThrowErrorIfRemovingOwnerFromEmptyIndex(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.MultiOwnable_NoOwnerAtIndex.selector, 5));
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(5, abi.encode(owner));
    }

    function test_ThrowErrorIfWrongOwnerAtIndex(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiOwnable.MultiOwnable_WrongOwnerAtIndex.selector, 0, abi.encode(owner), abi.encode(INITIAL_OWNER)
            )
        );
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(owner));
    }

    function test_ThrowErrorIfNonOwnerRemovesOwner(address nonOwner) public {
        vm.assume(nonOwner != INITIAL_OWNER);
        vm.assume(nonOwner != address(0));
        vm.assume(nonOwner != TEST_ACCOUNT_ADDRESS);
        vm.assume(nonOwner != address(networkConfig.entryPointAddress));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.MultiOwnable_Unauthorized.selector));
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVE LAST OWNER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldRemoveLastOwnerCorrectly() public {
        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(INITIAL_OWNER));

        assertFalse(JustanAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);
        assertEq(JustanAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);
    }

    function test_ThrowErrorIfRemoveLastOwnerWithMultipleOwners(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustanAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.MultiOwnable_NotLastOwner.selector, 2));
        JustanAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(INITIAL_OWNER));
    }

}
