// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";
import {MultiOwnable} from "../../src/MultiOwnable.sol";

contract TestMultiOwnableWithOwners is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;

    address public INITIAL_OWNER;
    uint256 public INITIAL_OWNER_PK;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, networkConfig) = deployer.run();

        (INITIAL_OWNER, INITIAL_OWNER_PK) = makeAddrAndKey("INITIAL_OWNER");

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(INITIAL_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIAL OWNERSHIP CHECK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnTrueForOwnerAddress() public view {
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
    }

    function test_ShouldReturnFalseForNonOwnerAddress(address nonOwner) public view {
        vm.assume(nonOwner != INITIAL_OWNER);

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(nonOwner));
    }

    function test_ShouldReturnTrueForOwnerPublicKey(bytes32 x, bytes32 y) public {
        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);

        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(x, y));
    }

    function test_ShouldReturnFalseForNonOwnerPublicKey(bytes32 x, bytes32 y) public view {
        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(x, y));
    }

    function test_ShouldReturnTrueForOwnerBytes() public view {
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerBytes(abi.encode(INITIAL_OWNER)));
    }

    function test_ShouldReturnFalseForNonOwnerBytes(address nonOwner) public view {
        vm.assume(nonOwner != INITIAL_OWNER);

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerBytes(abi.encode(nonOwner)));
    }

    function test_ShouldReturnCorrectOwnerAtIndex() public view {
        bytes memory ownerBytes = JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(0);
        assertEq(ownerBytes, abi.encode(INITIAL_OWNER));
    }

    function test_ShouldReturnEmptyBytesForEmptyIndex() public view {
        bytes memory ownerBytes = JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(5);
        assertEq(ownerBytes.length, 0);
    }

    function test_ShouldReturnCorrectNextOwnerIndex() public view {
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).nextOwnerIndex(), 1);
    }

    function test_ShouldReturnCorrectOwnerCount() public view {
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
    }

    function test_ShouldReturnZeroRemovedOwnersCount() public view {
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 0);
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
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).nextOwnerIndex(), 2);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(owner));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(1), abi.encode(owner));
    }

    function test_ThrowErrorIfAddingDuplicateOwnerAddress() public {
        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.AlreadyOwner.selector, abi.encode(INITIAL_OWNER)));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(INITIAL_OWNER);
    }

    function test_ThrowErrorIfNonOwnerAddsOwnerAddress(address nonOwner) public {
        vm.assume(nonOwner != INITIAL_OWNER);
        vm.assume(nonOwner != address(0));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.Unauthorized.selector));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(nonOwner);
    }

    /*//////////////////////////////////////////////////////////////
                       ADD OWNER PUBLIC KEY TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldAddOwnerPublicKeyCorrectly(bytes32 x, bytes32 y) public {
        vm.expectEmit(true, false, false, false, TEST_ACCOUNT_ADDRESS);
        emit MultiOwnable.AddOwner(1, abi.encode(x, y));

        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);

        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 2);
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).nextOwnerIndex(), 2);
        assertTrue(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerPublicKey(x, y));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerAtIndex(1), abi.encode(x, y));
    }

    function test_ThrowErrorIfAddingDuplicateOwnerPublicKey(bytes32 x, bytes32 y) public {
        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);

        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.AlreadyOwner.selector, abi.encode(x, y)));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);
    }

    function test_ThrowErrorIfNonOwnerAddsOwnerPublicKey(address nonOwner, bytes32 x, bytes32 y) public {
        vm.assume(nonOwner != INITIAL_OWNER);
        vm.assume(nonOwner != address(0));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.Unauthorized.selector));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerPublicKey(x, y);
    }

    /*//////////////////////////////////////////////////////////////
                      REMOVE OWNER AT INDEX TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldRemoveOwnerAtIndexCorrectly(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.expectEmit(true, false, false, false, TEST_ACCOUNT_ADDRESS);
        emit MultiOwnable.RemoveOwner(0, abi.encode(INITIAL_OWNER));

        vm.prank(owner);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 1);
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);
    }

    function test_ThrowErrorIfRemovingLastOwner() public {
        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.LastOwner.selector));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));
    }

    function test_ThrowErrorIfRemovingOwnerFromEmptyIndex(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.NoOwnerAtIndex.selector, 5));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(5, abi.encode(owner));
    }

    function test_ThrowErrorIfWrongOwnerAtIndex(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.WrongOwnerAtIndex.selector, 0, abi.encode(owner), abi.encode(INITIAL_OWNER)));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(owner));
    }

    function test_ThrowErrorIfNonOwnerRemovesOwner(address nonOwner) public {
        vm.assume(nonOwner != INITIAL_OWNER);
        vm.assume(nonOwner != address(0));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.Unauthorized.selector));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeOwnerAtIndex(0, abi.encode(INITIAL_OWNER));
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVE LAST OWNER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldRemoveLastOwnerCorrectly() public {
        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(INITIAL_OWNER));

        assertFalse(JustaNameAccount(TEST_ACCOUNT_ADDRESS).isOwnerAddress(INITIAL_OWNER));
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).ownerCount(), 0);
        assertEq(JustaNameAccount(TEST_ACCOUNT_ADDRESS).removedOwnersCount(), 1);
    }

    function test_ThrowErrorIfRemoveLastOwnerWithMultipleOwners(address owner) public {
        vm.assume(owner != INITIAL_OWNER);
        vm.assume(owner != address(0));

        vm.prank(INITIAL_OWNER);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).addOwnerAddress(owner);

        vm.prank(INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.NotLastOwner.selector, 2));
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).removeLastOwner(0, abi.encode(INITIAL_OWNER));
    }
}