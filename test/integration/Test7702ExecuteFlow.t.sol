// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";

contract Test7702ExecuteFlow is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;
    ERC20Mock public mockERC20;

    address public entryPointAddress;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, entryPointAddress) = deployer.run();

        mockERC20 = new ERC20Mock();
    }

    function test_ShouldExecute7702FlowCorrectly(address to, uint256 amount, bytes32 messageHash) public {
        vm.assume(to != address(0));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_ACCOUNT_PRIVATE_KEY, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        bytes4 result = JustaNameAccount(TEST_ACCOUNT_ADDRESS).isValidSignature(messageHash, signature);
        assertEq(result, bytes4(0x1626ba7e));

        bytes memory mintData = abi.encodeCall(ERC20Mock.mint, (to, amount));
        bytes memory burnData = abi.encodeCall(ERC20Mock.burn, (to, amount));

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).execute(address(mockERC20), 0, mintData);

        assertEq(mockERC20.balanceOf(to), amount);

        JustaNameAccount.Call[] memory calls = new JustaNameAccount.Call[](2);
        calls[0] = JustaNameAccount.Call({target: address(mockERC20), value: 0, data: burnData});
        calls[1] = JustaNameAccount.Call({target: address(mockERC20), value: 0, data: mintData});

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        vm.prank(TEST_ACCOUNT_ADDRESS);
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).executeBatch(calls);

        assertEq(mockERC20.balanceOf(to), amount);
    }
}
