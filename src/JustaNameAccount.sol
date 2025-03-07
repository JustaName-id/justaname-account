// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Receiver} from "@solady/accounts/Receiver.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {BaseAccount} from "@account-abstraction/core/BaseAccount.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {Exec} from "@account-abstraction/utils/Exec.sol";
import "@account-abstraction/core/Helpers.sol";

/**
 * @title JustaNameAccount
 * @notice This contract is to be usedt with EIP-7702 (for batching) and supports ERC-4337 (for gas sponsoring)
 */
contract JustaNameAccount is BaseAccount, Receiver {
    error JustaNameAccount_NotOwnerorEntryPoint();
    error JustaNameAccount_ExecuteError(uint256 index, bytes error);

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPointAddress) {
        i_entryPoint = IEntryPoint(entryPointAddress);
    }

    /**
     * @notice execute a single call from the account.
     */
    function execute(address target, uint256 value, bytes calldata data) external virtual {
        _requireForExecute();

        bool success = Exec.call(target, value, data, gasleft());
        if (!success) {
            Exec.revertWithData(Exec.getReturnData(0));
        }
    }

    /**
     * @notice execute a batch of calls.
     * @dev revert on the first call that fails.
     * If the batch reverts, and it contains more than a single call, then wrap the revert with ExecuteError,
     *  to mark the failing call index.
     */
    function executeBatch(Call[] calldata calls) external virtual {
        _requireForExecute();

        uint256 callsLength = calls.length;
        for (uint256 i = 0; i < callsLength; i++) {
            Call calldata call = calls[i];
            bool success = Exec.call(call.target, call.value, call.data, gasleft());
            if (!success) {
                if (callsLength == 1) {
                    Exec.revertWithData(Exec.getReturnData(0));
                } else {
                    revert JustaNameAccount_ExecuteError(i, Exec.getReturnData(0));
                }
            }
        }
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return i_entryPoint;
    }

    /**
     * @notice Validates the signature of the account.
     * @param hash The hash of the message to be signed.
     * @param signature The signature of the message.
     * @return result The result of the signature validation.
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) public view returns (bytes4 result) {
        bool success = _checkSignature(hash, signature);
        assembly {
            // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
            // We use `0xffffffff` for invalid, in convention with the reference implementation.
            result := shl(224, or(0x1626ba7e, sub(0, iszero(success))))
        }
    }

    /**
     * @notice Validates the signature of the account.
     * @dev Called by the entry point.
     * @param userOp The user operation.
     * @param userOpHash The hash of the user operation.
     * @return validationData The result of the signature validation.
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        return _checkSignature(userOpHash, userOp.signature) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    /**
     * @notice Validates signature.
     * @dev Checks whether the recovered address is equal to the account address.
     */
    function _checkSignature(bytes32 hash, bytes calldata signature) internal view returns (bool) {
        return ECDSA.recoverCalldata(hash, signature) == address(this);
    }

    // This function makes sure the caller is the owner or the entry point
    function _requireForExecute() internal view {
        require(
            msg.sender == address(this) || msg.sender == address(entryPoint()), JustaNameAccount_NotOwnerorEntryPoint()
        );
    }
}
