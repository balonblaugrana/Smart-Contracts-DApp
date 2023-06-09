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

contract AristoswapTestnet is OwnableUpgradeable, UUPSUpgradeable, EIP712 {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public biscouitToken;
    address public daoWallet;
    address[] public partnersCollections;
    address[] private projectCollections;
    
    mapping(address => uint256) public userNonce;
    mapping(bytes32 => bool) public cancelledOrFilled;

    address public wcro;

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
    error SwapsDontMatch();
    error FeesNotPaid();
    error WrongToken();

    /*//////////////////////////////////////////////////////////////
                          PROXY INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address[2] memory _projectCollections, 
        address _daoWallet, 
        address _biscouitToken,
        address _wcro
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
        wcro = _wcro;
        _transferOwnership(0xef1884424aBfcaE0A2bA60862B8C84d1f1Ef0686);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice 
    /// @param maker Input of msg.sender
    /// @param taker Input of counterparty
    function makeSwap(Input calldata maker, Input calldata taker, address feeToken) external payable {
        bytes32 makerHash = _hashSwap(maker.makerSwap, userNonce[maker.makerSwap.trader]);
        bytes32 takerHash = _hashSwap(taker.makerSwap, userNonce[taker.makerSwap.trader]);
        
        if (_validateSwapParameters(maker.makerSwap, makerHash) == false) revert InvalidSwap(0);
        if (_validateSwapParameters(taker.makerSwap, takerHash) == false) revert InvalidSwap(1);

        if (_validateSignatures(maker, makerHash) == false) revert InvalidAuthorization(0);
        if (_validateSignatures(taker, takerHash) == false) revert InvalidAuthorization(1);

        if (_validateFees(feeToken, taker.makerSwap.amount) == false ) revert FeesNotPaid();

        cancelledOrFilled[makerHash] = true;
        cancelledOrFilled[takerHash] = true;

        _executeFundsTransfer(taker.makerSwap.trader, maker.makerSwap.trader, maker.makerSwap.amount, 0);
        _executeFundsTransfer(maker.makerSwap.trader, taker.makerSwap.trader, taker.makerSwap.amount, 1);

        if (_validateMatchingSwaps(maker.makerSwap, taker.takerSwap) == false) revert SwapsDontMatch();
        if (_validateMatchingSwaps(maker.takerSwap, taker.makerSwap) == false) revert SwapsDontMatch();


        _executeTokensTransfer(
            maker.makerSwap.trader, 
            taker.makerSwap.trader, 
            maker.makerSwap.collections, 
            maker.makerSwap.tokenIds, 
            maker.makerSwap.assetTypes
        );
        _executeTokensTransfer(
            taker.makerSwap.trader, 
            maker.makerSwap.trader, 
            taker.makerSwap.collections, 
            taker.makerSwap.tokenIds, 
            taker.makerSwap.assetTypes
        );

        emit SwapsMatched(maker.makerSwap, taker.makerSwap);
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
    function _validateMatchingSwaps(Swap calldata maker, Swap calldata taker) internal pure returns (bool) {
        return (
            maker.amount == taker.amount && 
            maker.collections.length == taker.collections.length && 
            maker.tokenIds.length == taker.tokenIds.length && 
            maker.assetTypes.length == taker.assetTypes.length
        );
    }

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
        if (input.makerSwap.trader == msg.sender) {
            return true;
        }
        if (_validateUserAuthorization(swapHash, input.makerSwap.trader, input.v, input.r, input.s) == false) {
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
        //require( v == 0 || v == 0, "Invalid recovery id");
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
