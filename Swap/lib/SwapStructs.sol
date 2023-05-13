// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum AssetType {
    ERC721,
    ERC1155
}

/// @notice Struct for swap info
/// @param trader Address of the trader
/// @param amount CRO amount to send to the counterparty
/// @param collections Array of collection addresses
/// @param tokenIds Array of token ids
/// @param assetTypes Array of asset types
/// @dev collections, tokenIds and assetTypes are in the same order and have the same length
struct Swap {
    address trader;
    uint96 amount;
    address[] collections;
    uint256[] tokenIds;
    AssetType[] assetTypes;
}

/// @notice Struct for input data for the makerSwap function
/// @param makerSwap Swap info about the user
/// @param takerSwap Swap info about the counterparty
/// @param v ECDSA signature parameter v, chain id
/// @param r ECDSA signature parameter r
/// @param s ECDSA signature parameter s
struct Input {
    Swap makerSwap;
    Swap takerSwap;
    uint8 v;
    bytes32 r;
    bytes32 s;
}