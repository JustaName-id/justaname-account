// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console, Vm} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import "@account-abstraction/core/Helpers.sol";

import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {DeployJustaNameAccount} from "../../script/DeployJustaNameAccount.s.sol";
import {JustaNameAccount} from "../../src/JustaNameAccount.sol";
import {PreparePackedUserOp} from "../../script/PreparePackedUserOp.s.sol";


contract Test4337JustaNameAccount is Test, CodeConstants {
    JustaNameAccount public justaNameAccount;
    HelperConfig public helperConfig;
    ERC20Mock public mockERC20;
    PreparePackedUserOp public preparePackedUserOp;

    HelperConfig.NetworkConfig public networkConfig;

    function setUp() public {
        DeployJustaNameAccount deployer = new DeployJustaNameAccount();
        (justaNameAccount, networkConfig) = deployer.run();

        mockERC20 = new ERC20Mock();
        preparePackedUserOp = new PreparePackedUserOp();
    }

    /*//////////////////////////////////////////////////////////////
                         VALIDATE USEROP TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ThrowErrorIfCallingValidateUserOpFromNotEntrypoint(
        address sender,
        bytes memory callData,
        uint256 missingAccountFunds
    ) public {
        vm.assume(sender != networkConfig.entryPointAddress);
        vm.assume(sender != address(0));

        (PackedUserOperation memory userOp, bytes32 userOpHash) = preparePackedUserOp.generateSignedUserOperation(
            callData,
            networkConfig.entryPointAddress
        );

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        vm.prank(sender);
        vm.expectRevert("account: not from EntryPoint");
        JustaNameAccount(TEST_ACCOUNT_ADDRESS).validateUserOp(userOp, userOpHash, missingAccountFunds);
    }
    
    // TODO: test the payPrefund function
    function test_ShouldValidateUserOpCorrectly(
        bytes memory callData
    ) public {
        (PackedUserOperation memory userOp, bytes32 userOpHash) = preparePackedUserOp.generateSignedUserOperation(
            callData, 
            networkConfig.entryPointAddress
        );

        vm.signAndAttachDelegation(address(justaNameAccount), TEST_ACCOUNT_PRIVATE_KEY);
        vm.prank(networkConfig.entryPointAddress);
        uint256 validationData = JustaNameAccount(TEST_ACCOUNT_ADDRESS).validateUserOp(userOp, userOpHash, 0);

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    /*//////////////////////////////////////////////////////////////
                              EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ShouldExecuteCallCorrectly(
        address sender,
        uint256 amount
    ) public {
        vm.assume(sender != networkConfig.entryPointAddress);
        vm.assume(sender != address(0));

        bytes memory functionData = abi.encodeWithSelector(mockERC20.mint.selector, address(TEST_ACCOUNT_ADDRESS), amount);
        bytes memory executeCallData = abi.encodeWithSelector(justaNameAccount.execute.selector, address(mockERC20), 0, functionData);
        (PackedUserOperation memory userOp, bytes32 userOpHash) = preparePackedUserOp.generateSignedUserOperation(
            executeCallData, networkConfig.entryPointAddress, TEST_ACCOUNT_ADDRESS
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.prank(sender);
        IEntryPoint(networkConfig.entryPointAddress).handleOps(ops, payable(sender));

        assertEq(mockERC20.balanceOf(TEST_ACCOUNT_ADDRESS), amount);
    }
}
