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
}
