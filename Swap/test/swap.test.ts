import { signTypedData, SignTypedDataVersion } from "@metamask/eth-sig-util";

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { sign } from "crypto";
import { ethers , upgrades, network} from "hardhat";


let aristodogs: any, dogHouses: any, biscouitToken: any, exchange: any;
let alice: any, bob: any, owner: any;
let domain: any;
let swap: any;
let types: any;

interface Swap {
    trader: string;
    amount: number;
    collections: string[];
    tokenIds: number[];
    assetTypes: number[];
}

interface Input {
    makerSwap: Swap;
    takerSwap: Swap;
    v: number;
    r: string;
    s: string;
}



function hashSwap(swap: Swap, nonce: number): string {
    const SWAP_TYPEHASH = ethers.utils.id('Swap(address trader,uint96 amount,address[] collections,uint256[] tokenIds,uint8[] assetTypes)');
  
    const encodedData = ethers.utils.defaultAbiCoder.encode(
      ['bytes32', 'address', 'uint96', 'address[]', 'uint256[]', 'uint8[]', 'uint256'],
      [
        SWAP_TYPEHASH,
        swap.trader,
        swap.amount,
        swap.collections,
        swap.tokenIds,
        swap.assetTypes.map(type => type.valueOf()),
        nonce
      ]
    );
  
    return ethers.utils.keccak256(encodedData);
}

describe("Aristoswap", function () {
  before(async () => {
    [alice, bob, owner] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("MockERC721");
    const ERC20 = await ethers.getContractFactory("MockERC20");
    dogHouses = await NFT.deploy();
    aristodogs = await NFT.deploy();
    biscouitToken = await ERC20.deploy();

    await dogHouses.deployed();
    await aristodogs.deployed();
    await biscouitToken.deployed();

    const Swap = await ethers.getContractFactory("TestAristoswap");
    swap = await upgrades.deployProxy(Swap, [[dogHouses.address, aristodogs.address], owner.address, biscouitToken.address], {
      kind: "uups",
    });
    await swap.deployed();
    types = {
        Struct: [
          { name: "trader", type: "address" },
          { name: "amount", type: "uint96" },
          { name: "collections", type: "address[]" },
          { name: "tokenIds", type: "uint256[]" },
          { name: "assetTypes", type: "uint8[]" },
        ]
    };

    domain = {
        name: "Aristoswap", // contract deploy name
        version: "1.0", // contract deploy version
        chainId: 27, // env chain id
        verifyingContract: swap.address,
    };
  });
  describe("Signatures", () => {
    it("Signature should be valid", async () => {
        const makerSwap: Swap = {
            trader: alice.address,
            amount: 0,
            collections: [dogHouses.address],
            tokenIds: [1],
            assetTypes: [0]
        };
        const takerSwap: Swap = {
            trader: bob.address,
            amount: 0,
            collections: [aristodogs.address],
            tokenIds: [1],
            assetTypes: [0]
        };
        const signature = await alice._signTypedData(
            domain,
            types,
            makerSwap
        );
        const r = signature.slice(0, 66);
        const s = '0x' + signature.slice(66, 130);
        const v = '0x' + signature.slice(130, 132);
        let makerHash = hashSwap(makerSwap, 0);
        const makerInput: Input = {
            makerSwap: makerSwap,
            takerSwap: takerSwap,
            v: parseInt(v),
            r: r,
            s: s
        };
        expect (
            await swap.validateSignatures(makerInput, makerHash),
        ).to.be.true;
    });
    it("Signature should not be valid", async () => {
        const makerSwap: Swap = {
            trader: alice.address,
            amount: 0,
            collections: [dogHouses.address],
            tokenIds: [1],
            assetTypes: [0]
        };
        const takerSwap: Swap = {
            trader: bob.address,
            amount: 0,
            collections: [aristodogs.address],
            tokenIds: [1],
            assetTypes: [0]
        };
        const signature = await bob._signTypedData(
            domain,
            types,
            makerSwap
        );
        const r = signature.slice(0, 66);
        const s = '0x' + signature.slice(66, 130);
        const v = '0x' + signature.slice(130, 132);

        let makerHash = hashSwap(makerSwap, 0);
        const makerInput: Input = {
            makerSwap: makerSwap,
            takerSwap: takerSwap,
            v: parseInt(v),
            r: r,
            s: s
        };
        expect (
            await swap.connect(bob).validateSignatures(makerInput, makerHash),
        ).to.be.false;
    })
  })
});
