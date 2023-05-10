// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum AssetType {
    ERC721,
    ERC1155
}

struct Swap {
    address trader;
    uint96 croAmount;
    uint256[] tokensIds;
    address[] tokensAddresses;
    AssetType[] assetTypes;
    uint256 listingTime;
}