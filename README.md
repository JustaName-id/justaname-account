# JustaNameAccount

## Overview

The `JustaNameAccount` is a Solidity smart contract designed to enhance Ethereum account functionalities by integrating support for EIP-7702 and EIP-4337. These integrations enable features such as transaction batching, gas fee sponsorship, and advanced signature validation...

## Features

- **Multi-Owner Support**: Allows multiple owners to control the account, with flexible owner management including addition and removal of owners. This essentially allows the account to be used with advanced functionalities such as Coinbase's [SpendPermissionManager.sol](https://github.com/coinbase/spend-permissions).
- **Transaction Batching**: Allows the execution of multiple transactions in a single call, reducing overhead and improving efficiency.
- **Gas Sponsorship**: Supports mechanisms for third parties to sponsor gas fees, enabling users to interact with the Ethereum network without holding ETH.​
- **Signature Validation**: Implements the `isValidSignature` function in compliance with EIP-1271, facilitating contract-based signature verification.
- **Token Support**: Built-in support for receiving ERC-721 and ERC-1155 tokens
- **Namespaced Storage**: Uses ERC-7201 standard for collision-resistant storage layout

## Architecture

The contract consists of two main components:

### JustaNameAccount (Main Contract)

The primary account contract that inherits from:

- BaseAccount (ERC-4337 compliance)
- Receiver (Solady's receive functionality)
- MultiOwnable (Multi-owner management)
- IERC165, IERC1271 (Interface support)

#### Key Components

- `execute` Function: Executes a single transaction to a target address with specified value and data. Ensures that the caller is authorized (either the eoa through 7702, an account owner or the designated entry point).
- `executeBatch` Function: Executes multiple transactions in a single call. If any transaction fails, the function reverts, indicating the index of the failed transaction.
- `entryPoint` Function: Returns the entry point contract associated with this account, as required by EIP-4337.
- `isValidSignature` Function: Validates signatures according to EIP-1271, enabling contract-based signature verification.​
- `supportsInterface` Function: Indicates support for various interfaces, including ERC165, IAccount, IERC1271, IERC1155Receiver, and IERC721Receiver.

### MultiOwnable (Owner Management)

A separate contract that provides multi-owner functionality with:

- ERC-7201 Namespaced Storage: Prevents storage collisions using the storage slot 0x1860bbcd4070722545f3d4c498700ae30fda21f6bf1050d72d704cd0bd2cc100
- Flexible Owner Types: Stores owners as bytes to support future expansion beyond Ethereum addresses
- Index-based Management: Efficient owner tracking and removal using indices

#### Key Components

- addOwnerAddress(address owner): Adds a new Ethereum address as an owner
- removeOwnerAtIndex(uint256 index, bytes calldata owner): Removes an owner at a specific index
- isOwnerAddress(address account): Checks if an address is a registered owner
- isOwnerBytes(bytes memory account): Checks if bytes data represents a registered owner
- ownerAtIndex(uint256 index): Returns the owner data at a specific index
- ownerCount(): Returns the current number of active owners
- nextOwnerIndex(): Returns the next index to be used for owner addition

## Storage Layout

The contract uses ERC-7201 namespaced storage to prevent collisions:

```solidity
// Storage slot: keccak256(abi.encode(uint256(keccak256("justaname.storage.MultiOwnable")) - 1)) & ~bytes32(uint256(0xff))
bytes32 private constant MULTI_OWNABLE_STORAGE_LOCATION = 0x1860bbcd4070722545f3d4c498700ae30fda21f6bf1050d72d704cd0bd2cc100;
```
