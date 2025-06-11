// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Receiver} from "@solady/accounts/Receiver.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {BaseAccount} from "@account-abstraction/core/BaseAccount.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import "@account-abstraction/core/Helpers.sol";

import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {Exec} from "@account-abstraction/utils/Exec.sol";

import {MultiOwnable} from "./MultiOwnable.sol";

/**
 * @title JustaNameAccount
 * @notice This contract is to be used with EIP-7702 (for batching) and supports ERC-4337 (for gas sponsoring)
 */
contract JustaNameAccount is BaseAccount, Receiver, MultiOwnable, IERC165, IERC1271 {
    error JustaNameAccount_NotOwnerorEntryPoint();
    error JustaNameAccount_SelectorNotAllowed(bytes4 selector);
    error JustaNameAccount_InvalidNonceKey(uint256 key);

    IEntryPoint private immutable i_entryPoint;

    /**
     * @notice Reserved nonce key (upper 192 bits of `UserOperation.nonce`) for cross-chain replayable transactions.
     * @dev MUST BE the `UserOperation.nonce` key when `UserOperation.calldata` is calling
     * `executeWithoutChainIdValidation`and MUST NOT BE `UserOperation.nonce` key when `UserOperation.calldata` is
     *  NOT calling `executeWithoutChainIdValidation`.
     * @dev Helps enforce sequential sequencing of replayable transactions.
     *
     */
    uint256 public constant REPLAYABLE_NONCE_KEY = 8453;

    constructor(address entryPointAddress) {
        i_entryPoint = IEntryPoint(entryPointAddress);
    }

    /**
     * @notice Returns entrypoint used by this account
     */
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return i_entryPoint;
    }

    /**
     * @notice Executes `calls` on this account (i.e. self call).
     *
     * @dev Can only be called by the Entrypoint.
     * @dev Reverts if the given call is not authorized to skip the chain ID validtion.
     * @dev `validateUserOp()` will recompute the `userOpHash` without the chain ID before validating
     *  it if the `UserOperation.calldata` is calling this function. This allows certain UserOperations
     *  to be replayed for all accounts sharing the same address across chains. E.g. This may be
     * useful for syncing owner changes.
     * @param calls An array of calldata to use for separate self calls.
     */
    function executeWithoutChainIdValidation(bytes[] calldata calls) external payable virtual {
        _requireFromEntryPoint();

        for (uint256 i; i < calls.length; i++) {
            bytes calldata call = calls[i];
            bytes4 selector = bytes4(call);
            if (!canSkipChainIdValidation(selector)) {
                revert JustaNameAccount_SelectorNotAllowed(selector);
            }

            bool ok = Exec.call(address(this), 0, call, gasleft());

            // If the call fails, revert with the return data.
            if (!ok) {
                Exec.revertWithReturnData();
            }
        }
    }

    // add validateUserOp function to support without chain ID validation

    /**
     * @notice Validates the signature of the account.
     * @param hash The hash of the signed message.
     * @param signature The signature of the message.
     * @return result The result of the signature validation.
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 result) {
        bool success = _checkSignature(hash, signature);
        assembly {
            // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
            // We use `0xffffffff` for invalid, in convention with the reference implementation.
            result := shl(224, or(0x1626ba7e, sub(0, iszero(success))))
        }
    }

    /**
     * @notice Checks if the contract supports an interface.
     * @param id The interface ID.
     * @return Whether the contract supports the interface.
     */
    function supportsInterface(bytes4 id) public pure virtual returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IAccount).interfaceId || id == type(IERC1271).interfaceId
            || id == type(IERC1155Receiver).interfaceId || id == type(IERC721Receiver).interfaceId;
    }

    /**
     * @notice Returns whether `functionSelector` can be called in `executeWithoutChainIdValidation`.
     * @param functionSelector The function selector to check.
     * @return `true` if the function selector is allowed to skip the chain ID validation, else `false`.
     */
    function canSkipChainIdValidation(bytes4 functionSelector) public pure returns (bool) {
        if (
            functionSelector == MultiOwnable.addOwnerAddress.selector
                || functionSelector == MultiOwnable.removeOwnerAtIndex.selector
                || functionSelector == MultiOwnable.removeLastOwner.selector
        ) {
            return true;
        }
        return false;
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
     * @dev Checks whether the recovered address is equal to the account address or is an owner of this account.
     */
    function _checkSignature(bytes32 hash, bytes calldata signature) internal view returns (bool) {
        return ECDSA.recoverCalldata(hash, signature) == address(this)
            || isOwnerAddress(ECDSA.recoverCalldata(hash, signature));
    }

    /**
     * @notice This function makes sure the caller is an owner or the entrypoint
     * @dev called by `execute()` and `executeBatch()`.
     */
    function _requireForExecute() internal view override {
        require(
            msg.sender == address(this) || msg.sender == address(entryPoint()) || isOwnerAddress(msg.sender),
            JustaNameAccount_NotOwnerorEntryPoint()
        );
    }
}
