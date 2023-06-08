// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "src/Aristoswap.sol";

contract TestAristoswap is Aristoswap {
    function validateOrderParameters(Swap calldata swap, bytes32 hash)
        external
        view
        returns (bool)
    {
        return _validateSwapParameters(swap, hash);
    }

    function validateMatchingSwaps(Swap calldata makerSwap, Swap calldata takerSwap)
        external
        pure
        returns (bool)
    {
        return _validateMatchingSwaps(makerSwap, takerSwap);
    }

    function validateSignatures(Input calldata swap, bytes32 swapHash)
        external
        view
        returns (bool)
    {
        return _validateSignatures(swap, swapHash);
    }

    function hashSwap(Swap calldata swap, uint256 nonce)
        external
        pure
        returns (bytes32)
    {
        return _hashSwap(swap, nonce);
    }

    function hashToSign(bytes32 swapHash)
        external
        view
        returns (bytes32 hash)
    {
        return _hashToSign(swapHash);
    }
}
