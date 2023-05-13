// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Swap, AssetType, Input} from "lib/SwapStructs.sol";
import {EIP712} from "lib/EIP712.sol";

import "forge-std/console.sol";

contract Aristoswap is OwnableUpgradeable, UUPSUpgradeable, EIP712 {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public biscouitToken;
    address public daoWallet;
    address[] public partnersCollections;
    address[] private projectCollections;
    
    mapping(address => uint256) public userNonce;
    mapping(bytes32 => bool) public cancelledOrFilled;

    address public immutable wcro = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SwapsMatched(Swap makerSwap, Swap takerSwap);
    event NonceIncremented(address indexed user, uint256 newNonce);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidSwap(uint256 side); // 0 = maker, 1 = taker
    error InvalidAuthorization(uint256 side); // 0 = maker, 1 = taker
    error FeesNotPaid();
    error WrongToken();

    /*//////////////////////////////////////////////////////////////
                          PROXY INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address[2] memory _projectCollections, 
        address _daoWallet, 
        address _biscouitToken
    ) public initializer {
        __Ownable_init();

        DOMAIN_SEPARATOR = _hashDomain(
            EIP712Domain({
                name: "Aristoswap",
                version: "1.0",
                chainId: block.chainid,
                verifyingContract: address(this)
            })
        );
        projectCollections = _projectCollections;
        daoWallet = _daoWallet;
        biscouitToken = _biscouitToken;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function makeSwap(Input calldata maker, Input calldata taker, address feeToken) external payable {
        bytes32 makerHash = _hashSwap(maker.swap, userNonce[maker.swap.trader]);
        bytes32 takerHash = _hashSwap(taker.swap, userNonce[taker.swap.trader]);

        if (_validateSwapParameters(maker.swap, makerHash) == false) revert InvalidSwap(0);
        if (_validateSwapParameters(taker.swap, takerHash) == false) revert InvalidSwap(1);

        if (_validateSignatures(maker, makerHash) == false) revert InvalidAuthorization(0);
        if (_validateSignatures(taker, takerHash) == false) revert InvalidAuthorization(1);

        if (_validateFees(feeToken, taker.swap.amount) == false ) revert FeesNotPaid();

        _executeFundsTransfer(taker.swap.trader, maker.swap.trader, maker.swap.amount, 0);
        _executeFundsTransfer(maker.swap.trader, taker.swap.trader, taker.swap.amount, 1);

        _executeTokensTransfer(
            maker.swap.trader, 
            taker.swap.trader, 
            maker.swap.collections, 
            maker.swap.tokenIds, 
            maker.swap.assetTypes
        );
        _executeTokensTransfer(
            taker.swap.trader, 
            maker.swap.trader, 
            taker.swap.collections, 
            taker.swap.tokenIds, 
            taker.swap.assetTypes
        );

        emit SwapsMatched(maker.swap, taker.swap);
    }
    
    /// @notice Increment user's nonce to cancel pending swaps
    /// @dev Nonce will be invalid in the previous signed message by the user
    function cancelSwap() external {
        userNonce[msg.sender]++;
        emit NonceIncremented(msg.sender, userNonce[msg.sender]);
    }
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateFees(address feeToken, uint256 amount) internal returns (bool) {
        uint256 userFeesAmount = getUsersFeesAmount(msg.sender, feeToken);
        if (feeToken == address(0)) {
            return msg.value >= (userFeesAmount + amount);
        } else if (feeToken == biscouitToken) {
            require(IERC20(feeToken).transferFrom(msg.sender, address(this), userFeesAmount), "Fees not paid");
            return msg.value > amount;
        } else {
            return false;
        }
    }

    function _validateSwapParameters(Swap calldata swap, bytes32 _swapHash) internal view returns (bool) {
        return (
            cancelledOrFilled[_swapHash] == false && 
            swap.tokenIds.length < 9 && 
            swap.tokenIds.length == swap.collections.length && 
            swap.tokenIds.length == swap.assetTypes.length
        );
    }

    function _validateSignatures(Input calldata input, bytes32 swapHash) internal view returns (bool) {
        if (input.swap.trader == msg.sender) {
            return true;
        }

        if (_validateUserAuthorization(swapHash, input.swap.trader, input.v, input.r, input.s) == false) {
            return false;
        }

        return true;
    }

    function _validateUserAuthorization(
        bytes32 swapHash,
        address trader,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {
        bytes32 hashToSign = _hashToSign(swapHash);

        return _recover(hashToSign, v, r, s) == trader;
    }

    function _recover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        require(v == 25, "Invalid chainId"); 
        return ecrecover(digest, v, r, s);
    }

    function _executeTokensTransfer(
        address sender,
        address receiver,
        address[] memory collection,
        uint256[] memory tokenIds,
        AssetType[] memory assetTypes
    ) internal {
        for (uint256 i = 0; i < collection.length; i++) {
            if (assetTypes[i] == AssetType.ERC721) {
                IERC721(collection[i]).safeTransferFrom(sender, receiver, tokenIds[i]);
            } else {
                IERC1155(collection[i]).safeTransferFrom(sender, receiver, tokenIds[i], 1, "");
            }
        }
    }

    // makerSide = 0 -> wcro
    // takerSide = 1 -> cro
    function _executeFundsTransfer(address receiver, address sender, uint256 amount, uint256 side) internal {
        if (amount > 0) {
            if (side == 0) {
                (bool success,) = receiver.call{value: amount}("");
                require(success, "Transfer failed.");
            } else {
                IERC20(wcro).transferFrom(sender, receiver, amount);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getUsersFeesAmount(address _user, address _feeToken) public view virtual returns (uint256 amount) {
        if (isProjectHolder(_user)) {
            amount = 7.5 ether;
        } else if (isPartnerHolder(_user)) {
            amount = 15 ether;
        } else {
            amount = 20 ether;
        }
        if (_feeToken == biscouitToken) {
            amount = (amount / 2) * 100;
        }
    }

    function isProjectHolder(address _user) public view virtual returns (bool) {
        for (uint256 i = 0; i < projectCollections.length; i++) {
            if (IERC721(projectCollections[i]).balanceOf(_user) > 0) {
                return true;
            }
        }
        return false;
    }

    function isPartnerHolder(address _user) public view virtual returns (bool) {
        for (uint256 i = 0; i < partnersCollections.length; i++) {
            if (IERC721(partnersCollections[i]).balanceOf(_user) > 0) {
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    function withdraw() external onlyOwner {
        (bool success,) = daoWallet.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawBiscouit() external onlyOwner {
        uint256 amount = IERC20(biscouitToken).balanceOf(address(this));
        require(IERC20(biscouitToken).transfer(daoWallet, amount), "Transfer failed.");
    }
}
