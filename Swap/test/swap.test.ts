import { Contract, Wallet, Signature } from 'ethers';
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SwapParameters, AssetType, Swap, Input, sign } from "./utils/signatures";
import { ZERO_ADDRESS } from './utils/utils';

let aliceSwapParameters: any, bobSwapParameters: any;
let aliceSwap: any, bobSwap: any;
let aliceSwapHash: string, bobSwapHash: string;
let aliceInput: any, bobInput: any;
describe("Aristoswap", function () {
    let swapParameters: SwapParameters;
    let alice: any, bob: any, owner: any, other: any;
    let dogHouses: Contract, aristodogs: Contract, biscouitToken: Contract;
    let exchange: Contract;
    before(async () => {
        [alice, bob, other, owner] = await ethers.getSigners();
        console.log("Alice address: ", alice.address);
        console.log("Bob address: ", bob.address);
        const NFT = await ethers.getContractFactory("MockERC721");
        const ERC20 = await ethers.getContractFactory("MockERC20");
        dogHouses = await NFT.deploy();
        aristodogs = await NFT.deploy();
        biscouitToken = await ERC20.deploy();
    
        await dogHouses.deployed();
        await aristodogs.deployed();
        await biscouitToken.deployed();
    
        const Swap = await ethers.getContractFactory("TestAristoswap");
        exchange = await upgrades.deployProxy(Swap, [[dogHouses.address, aristodogs.address], owner.address, biscouitToken.address], {
          kind: "uups",
        });
        await exchange.deployed();
    });
    describe("Signatures", () => {
        beforeEach(async () => {
            aliceSwapParameters = {
                trader: alice.address,
                amount: ethers.utils.parseEther("0"), 
                collections: [aristodogs.address], 
                tokenIds: [1], 
                assetTypes: [AssetType.ERC721] 
            };
            aliceSwap = new Swap(alice, aliceSwapParameters, exchange);
            aliceSwapHash = await aliceSwap.hash();
            bobSwapParameters = {
                trader: bob.address,
                amount: ethers.utils.parseEther("0"), 
                collections: [aristodogs.address], 
                tokenIds: [2], 
                assetTypes: [AssetType.ERC721] 
            };
            bobSwap = new Swap(bob, bobSwapParameters, exchange);
            bobSwapHash = await bobSwap.hash();
            aliceInput = await aliceSwap.pack({signer: alice}, bobSwapParameters);
            bobInput = await bobSwap.pack({signer: bob}, aliceSwapParameters);
        });
        it("Sent by trader no signatures, should be valid", async () => {
            aliceInput = await aliceSwap.packNoSigs(bobSwapParameters);
            expect(
                await exchange.connect(alice).validateSignatures(aliceInput, aliceSwapHash)
            ).to.be.true;
        });
        it("Not sent by trader no signatures, should not be invalid", async () => {
            aliceInput = await aliceSwap.packNoSigs(bobSwapParameters);
            expect(
                await exchange.connect(other).validateSignatures(aliceInput, aliceSwapHash)
            ).to.be.false;
        });
        it("Not sent by trader, valid signatures, should be valid", async () => {
            expect(
                await exchange.connect(other).validateSignatures(aliceInput, aliceSwapHash)
            ).to.be.true;
        });
        it("Different signer, should not be valid", async () => {
            aliceInput = await aliceSwap.pack({signer: bob}, bobSwapParameters);
            expect(
                await exchange.connect(other).validateSignatures(aliceInput, aliceSwapHash)
            ).to.be.false;
        });
    });
    describe("Swap", () => {
        beforeEach(async () => {
            await aristodogs.mint(alice.address, 1);
            await aristodogs.mint(bob.address, 2);
            await aristodogs.connect(bob).setApprovalForAll(exchange.address, true);
            await aristodogs.connect(alice).setApprovalForAll(exchange.address, true);
            aliceSwapParameters = {
                trader: alice.address,
                amount: ethers.utils.parseEther("0"), 
                collections: [aristodogs.address], 
                tokenIds: [1], 
                assetTypes: [AssetType.ERC721] 
            };
            aliceSwap = new Swap(alice, aliceSwapParameters, exchange);
            aliceSwapHash = await aliceSwap.hash();
            bobSwapParameters = {
                trader: bob.address,
                amount: ethers.utils.parseEther("0"), 
                collections: [aristodogs.address], 
                tokenIds: [2], 
                assetTypes: [AssetType.ERC721] 
            };
            bobSwap = new Swap(bob, bobSwapParameters, exchange);
            bobSwapHash = await bobSwap.hash();
            aliceInput = await aliceSwap.pack({signer: alice}, bobSwapParameters);
            bobInput = await bobSwap.pack({signer: bob}, aliceSwapParameters);
        });
        it("Should swap between two traders", async () => {
            console.log("alice input ", aliceInput);
            console.log("bob input ", bobInput);
            const aliceNonce = await exchange.userNonce(alice.address);
            const hashFromContract = await exchange.hashSwap(aliceSwap.parameters, aliceNonce);
            //expect(hashFromContract).to.equal(aliceSwapHash);
            await exchange.connect(other).makeSwap(aliceInput, bobInput, ZERO_ADDRESS);
        });
    });
  });