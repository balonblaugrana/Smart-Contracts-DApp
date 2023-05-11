// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Aristoswap.sol";

import {Swap, AssetType} from "../lib/SwapStruct.sol";
import {Utilities} from "./utils/Utilities.sol";

import {mockERC20} from "src/mock/mockERC20.sol";
import {mockERC721} from "src/mock/mockERC721.sol";
import {mockERC1155} from "src/mock/mockERC1155.sol";

contract AristoswapTest is DSTest {
    Aristoswap internal swap;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;

    address[] internal users;
    address internal owner;
    address internal dao;

    mockERC20 internal biscouitToken;
    mockERC20 internal token1;
    mockERC20 internal token2;
    mockERC20 internal token3;

    mockERC721 internal aristodogs;
    mockERC721 internal dogHouses;
    mockERC721 internal nft1;
    mockERC721 internal nft2;
    mockERC721 internal nft3;

    mockERC1155 internal mockNFT1155;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(6);
        owner = users[0];
        dao = users[1];

        biscouitToken = new mockERC20();
        token1 = new mockERC20();
        token2 = new mockERC20();
        token3 = new mockERC20();

        aristodogs = new mockERC721();
        dogHouses = new mockERC721();
        nft1 = new mockERC721();
        nft2 = new mockERC721();
        nft3 = new mockERC721();

        mockNFT1155 = new mockERC1155();


        vm.startPrank(owner);
        swap = new Aristoswap(
            [address(aristodogs), address(dogHouses)],
            dao,
            address(biscouitToken)
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);
    }

    function _mintNft(address user, mockERC721 nftContract, uint256 amount) internal {
        nftContract.mint(user, amount);
        vm.prank(user);
        nftContract.setApprovalForAll(address(swap), true);
    }

    function _mintErc1155(address user, mockERC1155 nftContract, uint256 amount) internal {
        nftContract.mint(user, 1, amount);
        vm.prank(user);
        nftContract.setApprovalForAll(address(swap), true);
    }

    function testDeployment_ShouldSetRightValues_WhenDeployed() public {
        assertEq(swap.owner(), owner);
        assertEq(swap.daoWallet(), dao);
        assertEq(swap.biscouitToken(), address(biscouitToken));
        assertEq(swap.swapId(), 0);
        assertEq(swap.projectCollections(0), address(aristodogs));
        assertEq(swap.projectCollections(1), address(dogHouses));
        bool status = swap.collectionAllowed(address(aristodogs));
        assert(status);
        status = swap.collectionAllowed(address(dogHouses));
        assert(status);
    }

    function testWithelistCollections_ShouldSucceed_WhenCalledByOwner() public {
        address[] memory collections = new address[](2);
        collections[0] = address(nft1);
        collections[1] = address(nft2);

        vm.prank(owner);
        swap.withelistCollections(collections);
        bool status = swap.collectionAllowed(address(nft1));
        assert(status);
        status = swap.collectionAllowed(address(nft2));
        assert(status);
        status = swap.collectionAllowed(address(nft3));
        assert(!status);

        address collection1 = swap.allCollections(0);
        assertEq(collection1, address(nft1));
        address collection2 = swap.allCollections(1);
        assertEq(collection2, address(nft2));
    }

    function testWhitelistCollections_ShouldRevert_WhenNotCalledByOwner() public {
        address[] memory collections = new address[](2);
        collections[0] = address(nft1);
        collections[1] = address(nft2);

        vm.prank(users[2]);
        vm.expectRevert("Ownable: caller is not the owner");
        swap.withelistCollections(collections);
    }

    function testWhitelistCollections_ShouldRevert_WhenCollectionAlreadyWhitelisted() public {
        testWithelistCollections_ShouldSucceed_WhenCalledByOwner();
        address[] memory collections = new address[](2);
        collections[0] = address(nft1);
        collections[1] = address(nft3);

        vm.prank(owner);
        vm.expectRevert("Collection already whitelisted");
        swap.withelistCollections(collections);
    }

    function testWhitelistCollections_ShouldRevert_WhenCollectionIsNull() public {
        address[] memory collections = new address[](2);
        collections[0] = address(0);
        collections[1] = address(nft3);

        vm.prank(owner);
        vm.expectRevert("Invalid collection address");
        swap.withelistCollections(collections);
    }

    function testWhitelistTokens_ShouldSucceed_WhenCalledByOwner() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        vm.prank(owner);
        swap.withelistTokens(tokens);
        bool status = swap.feeTokenAllowed(address(token1));
        assert(status);
        status = swap.feeTokenAllowed(address(token2));
        assert(status);
        status = swap.feeTokenAllowed(address(token3));
        assert(!status);

        address token1Address = swap.allTokens(0);
        assertEq(token1Address, address(token1));
        address token2Address = swap.allTokens(1);
        assertEq(token2Address, address(token2));
    }

    function testWhitelistTokens_ShouldRevert_WhenNotCalledByOwner() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        vm.prank(users[2]);
        vm.expectRevert("Ownable: caller is not the owner");
        swap.withelistTokens(tokens);
    }

    function testWhitelistTokens_ShouldRevert_WhenTokenAlreadyWhitelisted() public {
        testWhitelistTokens_ShouldSucceed_WhenCalledByOwner();
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token3);

        vm.prank(owner);
        vm.expectRevert("Token already whitelisted");
        swap.withelistTokens(tokens);
    }

    function testWhitelistTokens_ShouldRevert_WhenTokenIsNull() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(token3);

        vm.prank(owner);
        vm.expectRevert("Invalid token address");
        swap.withelistTokens(tokens);
    }

    function _setSwap(address user, uint256 croAmount, uint256[] memory tokenIds, address[] memory collections, uint256 listingTime) internal returns (Swap memory swapUser) {
        uint256 collectionsLength = collections.length;
        AssetType[] memory assetTypes = new AssetType[](collectionsLength);
        for (uint256 i = 0; i < collectionsLength; i++) {
            if (
                collections[i] == address(aristodogs) || 
                collections[i] == address(dogHouses) || 
                collections[i] == address(nft1) ||
                collections[i] == address(nft2) ||
                collections[i] == address(nft3)
            ) {
                assetTypes[i] = AssetType.ERC721;
            } else {
                assetTypes[i] = AssetType.ERC1155;
            }
        }

        swapUser = Swap({
            trader: user,
            croAmount: uint96(croAmount),
            tokensIds: tokenIds,
            tokensAddresses: collections,
            assetTypes: assetTypes,
            listingTime: uint64(listingTime)
        });
    }

    function testCreateSwap_ShouldSucceed_WhenInputsAreValid() public {
        _mintNft(users[2], aristodogs, 2);
        _mintNft(users[3], dogHouses, 2);

        address[] memory collections = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        collections[0] = address(aristodogs);
        collections[1] = address(aristodogs);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        Swap memory swap1 = _setSwap(users[2], 0, tokenIds, collections, block.timestamp - 10 minutes);

        collections[0] = address(dogHouses);
        collections[1] = address(dogHouses);
        Swap memory swap2 = _setSwap(users[3], 0, tokenIds, collections, block.timestamp - 10 minutes);
        uint256 fees = 20 ether; // project holder
        vm.prank(users[2]);
        swap.createSwap{value: fees}(swap1, swap2, address(0));

        bool pendingSwapUser1 = swap.pendingSwap(users[2]);
        assert(pendingSwapUser1);
        bool pendingSwapUser2 = swap.pendingSwap(users[3]);
        assert(pendingSwapUser2);
        assertEq(swap.swapId(), 1);
    }

    function testCreateSwap_ShouldRevert_WhenCollectionIsNotAllowed() public {
        _mintNft(users[2], aristodogs, 1);
        _mintNft(users[2], nft1, 1);

        _mintNft(users[3], dogHouses, 2);

        address[] memory collections1 = new address[](2);
        uint256[] memory tokenIds1 = new uint256[](2);
        collections1[0] = address(aristodogs);
        collections1[1] = address(nft1);
        tokenIds1[0] = 1;
        tokenIds1[1] = 1;
        Swap memory swap1 = _setSwap(users[2], 0, tokenIds1, collections1, block.timestamp - 10 minutes);

        address[] memory collections2 = new address[](2);
        uint256[] memory tokenIds2 = new uint256[](2);
        collections2[0] = address(dogHouses);
        collections2[1] = address(dogHouses);
        tokenIds2[1] = 2;
        Swap memory swap2 = _setSwap(users[3], 0, tokenIds2, collections2, block.timestamp - 10 minutes);
        uint256 fees = 20 ether; // project holder
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Aristoswap.InvalidSwap.selector, 0));
        swap.createSwap{value: fees}(swap1, swap2, address(0));
    }
}
