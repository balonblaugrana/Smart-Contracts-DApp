// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Swap, AssetType } from "./SwapStructs.sol";

/**
 * @title EIP712
 * @dev Contains all of the swap hashing functions for EIP712 compliant signatures
 */
contract EIP712 {

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    /* Swap typehash for EIP 712 compatibility. */
    bytes32 constant public SWAP_TYPEHASH = keccak256(
        "Swap(address trader,uint96 amount,address[] collections,uint256[] tokenIds,uint8[] assetTypes,uint256 nonce)"
    );

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public DOMAIN_SEPARATOR;

    function _hashDomain(EIP712Domain memory eip712Domain)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function _hashSwap(Swap calldata swap, uint256 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                SWAP_TYPEHASH,
                swap.trader,
                swap.amount,
                keccak256(abi.encodePacked(swap.collections)),
                keccak256(abi.encodePacked(swap.tokenIds)),
                keccak256(abi.encodePacked(swap.assetTypes)),
                nonce
            )
        );
    }

    function _hashToSign(bytes32 swapHash)
        internal
        view
        returns (bytes32 hash)
    {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            swapHash
        ));
    }
}
