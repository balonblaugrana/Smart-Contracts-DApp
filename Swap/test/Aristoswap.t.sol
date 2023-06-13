// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { TestAristoswap } from "src/test/TestAristoswap.sol";
import { Swap, AssetType, Input } from "lib/SwapStructs.sol";

import {Utilities} from "./utils/Utilities.sol";

import {MockERC20} from "src/mock/MockERC20.sol";
import {MockERC721} from "src/mock/MockERC721.sol";
import {MockERC1155} from "src/mock/MockERC1155.sol";
import {MasterDog} from "src/mock/MasterDog.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AristoswapTest is DSTest {
    TestAristoswap internal swap;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;

    address[] internal users;
    address internal owner;
    address internal dao;

    uint256 internal bobKey = 0xDEAD;
    uint256 aliceKey = 0xBEEF;
    address internal alice;
    address internal bob;

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
        MasterDog masterDog = new MasterDog();

        vm.startPrank(owner);
        TestAristoswap implementation = new TestAristoswap();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        swap = TestAristoswap(address(proxy));
        swap.initialize([address(aristodogs), address(dogHouses)], dao, address(biscouitToken), address(masterDog));
        vm.stopPrank();

        alice = vm.addr(aliceKey);
        bob = vm.addr(bobKey);

        vm.warp(block.timestamp + 10 days);
    }

    function _getAliceSwap() public returns (Swap memory) {
        address[] memory collections = new address[](1);
        collections[0] = address(dogHouses);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        AssetType[] memory assetsType = new AssetType[](1);
        assetsType[0] = AssetType.ERC721;

        vm.startPrank(alice);
        dogHouses.mint(alice, 1);
        dogHouses.setApprovalForAll(address(swap), true);
        vm.stopPrank();

        Swap memory aliceSwap = Swap({
            trader: alice,
            amount: 0 ether,
            collections: collections,
            tokenIds: tokenIds,
            assetTypes: assetsType
        });
        return aliceSwap;
    }

    function _getBobSwap() public returns (Swap memory) {
        address[] memory collections = new address[](1);
        collections[0] = address(dogHouses);
        AssetType[] memory assetsType = new AssetType[](1);
        assetsType[0] = AssetType.ERC721;
        uint256[] memory bobTokenIds = new uint256[](1);
        bobTokenIds[0] = 2;

        vm.startPrank(bob);
        dogHouses.mint(bob, 2);
        dogHouses.setApprovalForAll(address(swap), true);
        vm.stopPrank();

        Swap memory bobSwap = Swap({
            trader: bob,
            amount: 100 ether,
            collections: collections,
            tokenIds: bobTokenIds,
            assetTypes: assetsType
        });

        return bobSwap;
    }

    function _getBobInput(Swap memory bobSwap, Swap memory aliceSwap) public view returns (Input memory) {
        bytes32 swapHash = swap.hashSwap(bobSwap, 0);
        bytes32 bobDigest = swap.hashToSign(swapHash);
        (uint8 sigBobV, bytes32 sigBobR, bytes32 sigBobS) = vm.sign(bobKey, bobDigest);

        Input memory input = Input({
            makerSwap: bobSwap,
            takerSwap: aliceSwap,
            v: sigBobV,
            r: sigBobR,
            s: sigBobS
        });

        return input;
    }

    function _getAliceInput(Swap memory aliceSwap, Swap memory bobSwap) public view returns (Input memory) {
        bytes32 swapHash = swap.hashSwap(aliceSwap, 0);
        bytes32 aliceDigest = swap.hashToSign(swapHash);
        (uint8 sigAliceV, bytes32 sigAliceR, bytes32 sigAliceS) = vm.sign(aliceKey, aliceDigest);

        Input memory input = Input({
            makerSwap: aliceSwap,
            takerSwap: bobSwap,
            v: sigAliceV,
            r: sigAliceR,
            s: sigAliceS
        });

        return input;
    }

    function testSignatures() public {
        address[] memory collections = new address[](1);
        collections[0] = address(aristodogs);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        AssetType[] memory assetsType = new AssetType[](1);
        assetsType[0] = AssetType.ERC721;

        vm.startPrank(alice);
        dogHouses.mint(alice, 1);
        dogHouses.setApprovalForAll(address(swap), true);

        Swap memory aliceSwap = Swap({
            trader: alice,
            amount: 0 ether,
            collections: collections,
            tokenIds: tokenIds,
            assetTypes: assetsType
        });

        uint256[] memory bobTokenIds = new uint256[](1);
        bobTokenIds[0] = 2;
        Swap memory bobSwap = Swap({
            trader: bob,
            amount: 0 ether,
            collections: collections,
            tokenIds: bobTokenIds,
            assetTypes: assetsType
        });
        bytes32 swapHash = swap.hashSwap(bobSwap, 0);
        bytes32 bobDigest = swap.hashToSign(swapHash);
        (uint8 sigBobV, bytes32 sigBobR, bytes32 sigBobS) = vm.sign(bobKey, bobDigest);
        Input memory input = Input({
            makerSwap: bobSwap,
            takerSwap: aliceSwap,
            v: sigBobV,
            r: sigBobR,
            s: sigBobS
        });
        assert(swap.validateSignatures(input, swapHash));
    }

    function testSwaps_ShouldMatch() public {
        Swap memory aliceSwap = _getAliceSwap();
        Swap memory bobSwap = _getBobSwap();
        Input memory aliceInput = _getAliceInput(aliceSwap, bobSwap);
        Input memory bobInput = _getBobInput(bobSwap, aliceSwap);
        
        assert(swap.validateMatchingSwaps(aliceInput.makerSwap, bobInput.takerSwap));
        assert(swap.validateMatchingSwaps(aliceInput.takerSwap, bobInput.makerSwap));
    }

    function testSwap_ShouldSucceed() public {
        Swap memory aliceSwap = _getAliceSwap();
        Swap memory bobSwap = _getBobSwap();

        Input memory aliceInput = _getAliceInput(aliceSwap, bobSwap);
        Input memory bobInput = _getBobInput(bobSwap, aliceSwap);

        vm.deal(bob, 10000000 ether);
        vm.startPrank(bob);
        swap.makeSwap{value: 120 ether}(bobInput, aliceInput, address(0));

        assertEq(dogHouses.ownerOf(1), bob);
        assertEq(dogHouses.ownerOf(2), alice);
    }
}
