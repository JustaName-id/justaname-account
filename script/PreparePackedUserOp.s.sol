// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CodeConstants} from "./HelperConfig.s.sol";

contract PreparePackedUserOp is Script, CodeConstants {
    using MessageHashUtils for bytes32;

    function generateSignedUserOperation(bytes memory callData, address entryPoint)
        public
        view
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        uint256 nonce = IEntryPoint(entryPoint).getNonce(TEST_ACCOUNT_ADDRESS, 0);
        userOp = _generateUnsignedUserOperation(callData, TEST_ACCOUNT_ADDRESS, nonce);

        userOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(TEST_ACCOUNT_PRIVATE_KEY, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        return (userOp, userOpHash);
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: abi.encodePacked(bytes20(0x7702000000000000000000000000000000000000)),
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
