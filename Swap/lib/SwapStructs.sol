// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum AssetType {
    ERC721,
    ERC1155
}

struct Swap {
    address trader;
    uint96 amount;
    address[] collections;
    uint256[] tokenIds;
    AssetType[] assetTypes;
}

struct Input {
    Swap swap;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 blockNumber;
}