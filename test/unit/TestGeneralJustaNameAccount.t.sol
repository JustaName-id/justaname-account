// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";

contract ERC721Mock is ERC721 {
    constructor() ERC721("ERC721Mock", "E721M") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract ERC1155Mock is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) public {
        _mint(to, tokenId, amount, data);
    }
}

contract TestGeneralJustaNameAccount is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;

    ERC721Mock public erc721Mock;
    ERC1155Mock public erc1155Mock;

    HelperConfig.NetworkConfig public networkConfig;

    address public NFT_OWNER;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, networkConfig) = deployer.run();

        NFT_OWNER = makeAddr("nft_owner");

        erc721Mock = new ERC721Mock();
        erc1155Mock = new ERC1155Mock();
    }

    /*//////////////////////////////////////////////////////////////
                          ENTRYPOINT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnCorrectEntryPoint() public view {
        address _entryPoint = address(justaNameAccount.entryPoint());
        assertEq(_entryPoint, networkConfig.entryPointAddress);
    }

    function test_ShouldReturnTrueIfCorrectInterface() public view {
        assertTrue(justaNameAccount.supportsInterface(type(IAccount).interfaceId));
        assertTrue(justaNameAccount.supportsInterface(type(IERC165).interfaceId));
        assertTrue(justaNameAccount.supportsInterface(type(IERC1271).interfaceId));
        assertTrue(justaNameAccount.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(justaNameAccount.supportsInterface(type(IERC1155Receiver).interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORTS INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnFalseIfIncorrectInterface(bytes4 _interfaceId) public view {
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
    function test_ShouldReturnFalseIfIncorrectSignature(bytes32 messageHash) public {
        (, uint256 alicePk) = makeAddrAndKey("alice");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, messageHash);
        bytes memory badSignature = abi.encodePacked(r, s, v);

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        bytes4 result = JustaNameAccount(TEST_ACCOUNT_ADDRESS).isValidSignature(messageHash, badSignature);
        assertEq(result, bytes4(0xffffffff));
    }

    function test_ShouldReturnTrueIfSignatureIsValid(bytes32 messageHash) public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_ACCOUNT_PRIVATE_KEY, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        bytes4 result = JustaNameAccount(TEST_ACCOUNT_ADDRESS).isValidSignature(messageHash, signature);
        assertEq(result, bytes4(0x1626ba7e));
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReceiveERC721Correctly(uint256 tokenId) public {
        erc721Mock.mint(NFT_OWNER, tokenId);

        vm.prank(NFT_OWNER);
        erc721Mock.approve(TEST_ACCOUNT_ADDRESS, tokenId);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        erc721Mock.safeTransferFrom(NFT_OWNER, TEST_ACCOUNT_ADDRESS, tokenId);

        assertEq(erc721Mock.balanceOf(TEST_ACCOUNT_ADDRESS), 1);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        erc721Mock.safeTransferFrom(TEST_ACCOUNT_ADDRESS, NFT_OWNER, tokenId);

        assertEq(erc721Mock.balanceOf(TEST_ACCOUNT_ADDRESS), 0);
    }

    function test_ShouldReceiveERC1155Correctly(uint256 tokenId, uint256 amount) public {
        erc1155Mock.mint(NFT_OWNER, tokenId, amount, bytes(""));

        vm.prank(NFT_OWNER);
        erc1155Mock.safeTransferFrom(NFT_OWNER, TEST_ACCOUNT_ADDRESS, tokenId, amount, bytes(""));

        assertEq(erc1155Mock.balanceOf(TEST_ACCOUNT_ADDRESS, tokenId), amount);

        vm.prank(TEST_ACCOUNT_ADDRESS);
        erc1155Mock.safeTransferFrom(TEST_ACCOUNT_ADDRESS, NFT_OWNER, tokenId, amount, bytes(""));

        assertEq(erc1155Mock.balanceOf(TEST_ACCOUNT_ADDRESS, tokenId), 0);
    }
}
