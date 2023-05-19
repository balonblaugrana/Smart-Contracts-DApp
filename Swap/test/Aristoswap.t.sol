// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Aristoswap.sol";

import {Utilities} from "./utils/Utilities.sol";

import {MockERC20} from "src/mock/MockERC20.sol";
import {MockERC721} from "src/mock/MockERC721.sol";
import {MockERC1155} from "src/mock/MockERC1155.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AristoswapTest is DSTest {
    Aristoswap internal swap;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;

    address[] internal users;
    address internal owner;
    address internal dao;

    MockERC20 internal biscouitToken;
    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    MockERC721 internal aristodogs;
    MockERC721 internal dogHouses;
    MockERC721 internal nft1;
    MockERC721 internal nft2;
    MockERC721 internal nft3;

    MockERC1155 internal mockNFT1155;

    bytes32 constant public SWAP_TYPEHASH = keccak256(
        "Swap(address trader,uint96 amount,address[] collections,uint256[] tokenIds,uint8[] assetTypes)"
    );

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(6);
        owner = users[0];
        dao = users[1];

        biscouitToken = new MockERC20();
        token1 = new MockERC20();
        token2 = new MockERC20();
        token3 = new MockERC20();

        aristodogs = new MockERC721();
        dogHouses = new MockERC721();
        nft1 = new MockERC721();
        nft2 = new MockERC721();
        nft3 = new MockERC721();

        mockNFT1155 = new MockERC1155();

        vm.startPrank(owner);
        Aristoswap implementation = new Aristoswap();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        swap = Aristoswap(address(proxy));
        swap.initialize([address(aristodogs), address(dogHouses)], dao, address(biscouitToken));
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);
    }

    function testSignatures() public {
        uint256 userKey = 0xBEEF;
        address alice = vm.addr(userKey);
        address[] memory collections = new address[](1);
        collections[0] = address(aristodogs);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        AssetType[] memory assetsType = new AssetType[](1);
        assetsType[0] = AssetType.ERC721;

        vm.startPrank(alice);
        dogHouses.mint(alice, 1);
        dogHouses.setApprovalForAll(address(swap), true);

        Swap memory swapStruct = Swap({
            trader: alice,
            amount: 100,
            collections: collections,
            tokenIds: tokenIds,
            assetTypes: assetsType
        });

        //bytes32 digest = TestAristoswap.hashSwap(swapStruct, 0);
        //(uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
    }
}
