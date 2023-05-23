import { TypedDataUtils, SignTypedDataVersion } from '@metamask/eth-sig-util';
import { Contract, Wallet, Signature, BigNumber, Signer } from 'ethers';
import { ethers } from "hardhat";
const { eip712Hash, hashStruct } = TypedDataUtils;
import { ZERO_BYTES32, ZERO_ADDRESS } from './utils';

export enum AssetType {
    ERC721 = 0,
    ERC1155 = 1,
}

export interface SwapParameters {
    trader: string;
    amount: BigNumber;
    collections: string[];
    tokenIds: string[] | number[];
    assetTypes: AssetType[];
}

export interface SwapWithNonce extends SwapParameters {
    nonce: any;
}

export interface Field {
    name: string;
    type: string;
  }
  
export interface Domain {
  name: string;
  version: string;
  chainId: number;
  verifyingContract: string;
}

export interface TypedData {
  name: string;
  fields: Field[];
  domain: Domain;
  data: SwapParameters;
}

export interface Input {
    makerSwap: SwapParameters;
    takerSwap: SwapParameters;
    v: number;
    r: string;
    s: string;
}

export class Swap {
    parameters: SwapParameters;
    user: any;
    exchange: any;
  
    constructor(
      user: any,
      parameters: SwapParameters,
      exchange: any,
    ) {
      this.user = user;
      this.parameters = parameters;
      this.exchange = exchange;
    }
  
    async hash(): Promise<string> {
      const nonce = await this.exchange.userNonce(this.parameters.trader);
      return hashWithoutDomain({ ...this.parameters, nonce });
    }
  
    async hashToSign(): Promise<string> {
      const nonce = await this.exchange.userNonce(this.parameters.trader);
      return hash({ ...this.parameters, nonce }, this.exchange);
    }
  
    async pack(
      options: { signer?: Signer; } = {},
      takerSwap: SwapParameters,
    ) {
      const signature = await sign(
        this.parameters,
        options.signer || this.user,
        this.exchange,
      );

      return {
        makerSwap: this.parameters,
        takerSwap: takerSwap,
        v: signature.v,
        r: signature.r,
        s: signature.s
      };
    }

    async packNoSigs(takerSwap: SwapParameters) {
        const chainId = (await ethers.provider.getNetwork()).chainId;
        return {
            makerSwap: this.parameters,
            takerSwap: takerSwap,
            v: 0,
            r: ZERO_BYTES32,
            s: ZERO_BYTES32,
        };
    }
}

export const eip712Swap = {
    name: 'Swap',
    fields: [
      { name: 'trader', type: 'address' },
      { name: 'amount', type: 'uint96' },
      { name: 'collections', type: 'address[]' },
      { name: 'tokenIds', type: 'uint256[]' },
      { name: 'assetTypes', type: 'uint8[]' },
      { name: 'nonce', type: 'uint256' },
    ],
};

export function structToSign(swap: SwapWithNonce, exchange: string): TypedData {
    return {
      name: eip712Swap.name,
      fields: eip712Swap.fields,
      domain: {
        name: 'Aristoswap',
        version: '1.0',
        chainId: 25,
        verifyingContract: exchange,
      },
      data: swap,
    };
}

export async function sign(
    swap: SwapParameters,
    account: Wallet,
    exchange: Contract,
  ): Promise<Signature> {
    const nonce = await exchange.userNonce(swap.trader);
    if (!nonce) {
        throw new Error('Nonce not found');
    }
    
    const str = structToSign({ ...swap, nonce: nonce }, exchange.address);
  
    return account
      ._signTypedData(
        str.domain,
        {
          [eip712Swap.name]: eip712Swap.fields,
        },
        str.data,
      )
      .then(async (sigBytes) => {
        const sig = ethers.utils.splitSignature(sigBytes);
        //if (sig.v == 27 || sig.v == 28) sig.v += (await ethers.provider./getNetwork()).chainId * 2 + 8;
        return sig;
      });
}

export function hash(parameters: any, exchange: Contract): string {
    parameters.nonce = parameters.nonce.toHexString();
    parameters.amount = parameters.amount.toString();
    return `0x${eip712Hash(
      {
        types: {
          EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
            { name: 'chainId', type: 'uint256' },
            { name: 'verifyingContract', type: 'address' },
          ],
          [eip712Swap.name]: eip712Swap.fields,
        },
        primaryType: 'Swap',
        domain: {
          name: 'Aristoswap',
          version: '1.0',
          chainId: 25,
          verifyingContract: exchange.address,
        },
        message: parameters,
      },
      SignTypedDataVersion.V4,
    ).toString('hex')}`;
}
  
export function hashWithoutDomain(parameters: any): string {
  parameters.nonce = parameters.nonce.toHexString();
  parameters.amount = parameters.amount.toString();
  return `0x${hashStruct(
    'Swap',
    parameters,
    {
      [eip712Swap.name]: eip712Swap.fields,
    },
    SignTypedDataVersion.V4,
  ).toString('hex')}`;
}