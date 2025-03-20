// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";

contract TestGeneralJustaNameAccount is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;

    address public entryPointAddress;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, entryPointAddress) = deployer.run();
    }

    /*//////////////////////////////////////////////////////////////
                          ENTRYPOINT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnCorrectEntryPoint() public view {
        address _entryPoint = address(justaNameAccount.entryPoint());
        assertEq(_entryPoint, entryPointAddress);
    }

    function test_ShouldReturnTrueIfCorrectInterface() public view {
        assertTrue(
            justaNameAccount.supportsInterface(type(IAccount).interfaceId)
        );
        assertTrue(
            justaNameAccount.supportsInterface(type(IERC165).interfaceId)
        );
        assertTrue(
            justaNameAccount.supportsInterface(type(IERC1271).interfaceId)
        );
        assertTrue(
            justaNameAccount.supportsInterface(
                type(IERC721Receiver).interfaceId
            )
        );
        assertTrue(
            justaNameAccount.supportsInterface(
                type(IERC1155Receiver).interfaceId
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORTS INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnFalseIfIncorrectInterface(
        bytes4 _interfaceId
    ) public view {
        vm.assume(_interfaceId != type(IAccount).interfaceId);
        vm.assume(_interfaceId != type(IERC165).interfaceId);
        vm.assume(_interfaceId != type(IERC1271).interfaceId);
        vm.assume(_interfaceId != type(IERC721Receiver).interfaceId);
        vm.assume(_interfaceId != type(IERC1155Receiver).interfaceId);

        assertFalse(justaNameAccount.supportsInterface(_interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                          VALID SIGNATURE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnFalseIfIncorrectSignature(
        bytes32 messageHash
    ) public {
        (, uint256 alicePk) = makeAddrAndKey("alice");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, messageHash);
        bytes memory badSignature = abi.encodePacked(r, s, v);

        vm.signAndAttachDelegation(
            address(justaNameAccount),
            TEST_ACCOUNT_PRIVATE_KEY
        );
        bytes4 result = JustaNameAccount(TEST_ACCOUNT_ADDRESS).isValidSignature(
            messageHash,
            badSignature
        );
        assertEq(result, bytes4(0xffffffff));
    }

    function test_ShouldReturnTrueIfSignatureIsValid(
        bytes32 messageHash
    ) public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            TEST_ACCOUNT_PRIVATE_KEY,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.signAndAttachDelegation(
            address(justaNameAccount),
            TEST_ACCOUNT_PRIVATE_KEY
        );
        bytes4 result = JustaNameAccount(TEST_ACCOUNT_ADDRESS).isValidSignature(
            messageHash,
            signature
        );
        assertEq(result, bytes4(0x1626ba7e));
    }
}
