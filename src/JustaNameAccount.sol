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

import {MultiOwnable} from "./MultiOwnable.sol";

/**
 * @title JustaNameAccount
 * @notice This contract is to be used with EIP-7702 (for batching) and supports ERC-4337 (for gas sponsoring)
 */
contract JustaNameAccount is BaseAccount, Receiver, MultiOwnable, IERC165, IERC1271 {
    error JustaNameAccount_NotOwnerOrEntryPoint();

    IEntryPoint private immutable i_entryPoint;

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
     */
    function _requireForExecute() internal view override {
        _checkOwnerOrEntryPoint();
    }

    /**
     * @notice Checks if the sender is an owner of this contract or the contract itself.
     * @dev Revert if the sender is not an owner fo the contract itself or the entrypoint.
     */
    function _checkOwnerOrEntryPoint() internal view virtual override {
        if (isOwnerAddress(msg.sender) || (msg.sender == address(this)) || (msg.sender == address(entryPoint()))) {
            return;
        }

        revert JustaNameAccount_NotOwnerOrEntryPoint();
    }
}
