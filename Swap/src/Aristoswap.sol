// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {Swap, AssetType} from "../lib/SwapStruct.sol";

import "forge-std/console.sol";

contract Aristoswap is Ownable {
    uint256 public swapId;

    address[] public projectCollections;
    address public immutable biscouitToken;
    address public immutable daoWallet;

    address[] public partnersCollections;

    mapping(uint256 => Swap) public makerSwapsById;
    mapping(uint256 => Swap) public takerSwapsById;

    mapping(address => uint256[]) public swapsByUser;
    mapping(address => bool) public pendingSwap;
    mapping(bytes32 => bool) public cancelledOrFilled;
    
    mapping(address => bool) public collectionAllowed;
    mapping(address => bool) public feeTokenAllowed;

    address[] public allCollections;
    address[] public allTokens;

    event SwapCreated(uint256 indexed swapId, address indexed maker, address indexed buyer);
    event SwapMatched(uint256 indexed swapId, address indexed maker, address indexed buyer);

    error NotEnoughFunds();
    error WrongCaller();
    error InvalidSwap(uint256 side); // 0 = maker, 1 = taker
    error FeesNotPaid();
    error UserHasPendingSwap();

    constructor(address[2] memory _projectCollections, address _daoWallet, address _biscouitToken) {
        projectCollections = _projectCollections;
        collectionAllowed[_projectCollections[0]] = true;
        collectionAllowed[_projectCollections[1]] = true;
        daoWallet = _daoWallet;
        biscouitToken = _biscouitToken;
    }

    function withelistCollections(address[] calldata collections) external onlyOwner {
        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];
            require(collection != address(0), "Invalid collection address");
            require(collectionAllowed[collection] == false, "Collection already whitelisted");
            collectionAllowed[collection] = true;
            allCollections.push(collection);
        }
    }

    function withelistTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token != address(0), "Invalid token address");
            require(feeTokenAllowed[token] == false, "Token already whitelisted");
            feeTokenAllowed[token] = true;
            allTokens.push(token);
        }
    }

    function createSwap(Swap calldata swapMaker, Swap calldata swapTaker, address feeToken) external payable {
        if (msg.sender != swapMaker.trader) revert WrongCaller();
        
        if (_validateFees(feeToken, swapMaker.croAmount) == false) revert FeesNotPaid();
        if (pendingSwap[msg.sender] == true) revert UserHasPendingSwap();
        if (_validateSwapParameters(swapMaker) == false) revert InvalidSwap(0);
        if (_validateSwapParameters(swapTaker) == false) revert InvalidSwap(1);

        uint256 currentSwapId = swapId + 1;
        makerSwapsById[currentSwapId] = swapMaker;
        takerSwapsById[currentSwapId] = swapTaker;
        swapsByUser[msg.sender].push(currentSwapId);
        swapsByUser[swapTaker.trader].push(currentSwapId);
        swapId = currentSwapId;
        pendingSwap[msg.sender] = true;
        pendingSwap[swapTaker.trader] = true;

        emit SwapCreated(currentSwapId, msg.sender, swapTaker.trader);
    }

    function acceptSwap(uint256 _swapId) external payable {
        Swap memory makerSwap = makerSwapsById[_swapId];
        Swap memory takerSwap = takerSwapsById[_swapId];
        if (msg.sender != takerSwap.trader) revert WrongCaller();
        if (takerSwap.croAmount < msg.value) revert NotEnoughFunds();

        bytes32 makerHash = _hashSwap(makerSwap);
        if (cancelledOrFilled[makerHash] == true) revert InvalidSwap(0);
        cancelledOrFilled[makerHash] = true;

        _executeTokensTransfer(
            makerSwap.trader, 
            takerSwap.trader, 
            makerSwap.tokensAddresses, 
            makerSwap.tokensIds, 
            makerSwap.assetTypes
        );

        _executeTokensTransfer(
            takerSwap.trader, 
            makerSwap.trader, 
            takerSwap.tokensAddresses, 
            takerSwap.tokensIds, 
            takerSwap.assetTypes
        );

        _executeFundsTransfer(takerSwap.trader, makerSwap.croAmount);
        _executeFundsTransfer(makerSwap.trader, takerSwap.croAmount);

        emit SwapMatched(_swapId, makerSwap.trader, takerSwap.trader);
    }

    function _validateFees(address feeToken, uint256 makerCroAmount) internal returns (bool) {
        
        uint256 userFeesAmount = getUsersFeesAmount(msg.sender, feeToken);
        if (feeToken == address(0)) {
            return msg.value >= (userFeesAmount + makerCroAmount);
        } else {
            if (feeTokenAllowed[feeToken] == false) {
                return false;
            }
            require(IERC20(feeToken).transferFrom(msg.sender, address(this), userFeesAmount), "Fees not paid");
            return msg.value > makerCroAmount;
        }
    }

    function _validateSwapParameters(Swap calldata swap) internal view returns (bool) {
        bytes32 swapHash = _hashSwap(swap);
        return (
            swap.listingTime < block.timestamp &&
            cancelledOrFilled[swapHash] == false &&
            swap.tokensIds.length < 9 &&
            swap.tokensIds.length == swap.tokensAddresses.length &&
            swap.tokensIds.length == swap.assetTypes.length &&
            _validateCollections(swap.tokensAddresses)
        );
    }

    function _validateCollections(address[] calldata collections) internal view returns (bool) {
        for (uint256 i = 0; i < collections.length; i++) {
            if (collectionAllowed[collections[i]] == false) {
                return false;
            }
        }
        return true;
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

    function _executeFundsTransfer(address receiver,uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = receiver.call{value: amount}("");
            require(success, "Transfer failed.");
        }
    } 

    function _hashSwap(Swap memory swap) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                swap.trader,
                swap.croAmount,
                keccak256(abi.encodePacked(swap.tokensIds)),
                keccak256(abi.encodePacked(swap.tokensAddresses)),
                keccak256(abi.encodePacked(swap.assetTypes)),
                swap.listingTime
            )
        );
    }

    function getUsersFeesAmount(address _user, address _feeToken) public virtual view returns (uint amount) {
        if (isProjectHolder(_user)) {
            amount = 7.5 ether;
        } else if (isPartnerHolder(_user)) {
            amount = 15 ether;
        } else {
            amount = 20 ether;
        }
        if (_feeToken == biscouitToken) {
            amount = amount - (amount * 10 / 100);
        }
    }

    function isProjectHolder(address _user) public virtual view returns (bool) {
        for (uint256 i = 0; i < projectCollections.length; i++) {
            if (IERC721(projectCollections[i]).balanceOf(_user) > 0) {
                return true;
            }
        }
        return false;
    }

    function isPartnerHolder(address _user) public virtual view returns (bool) {
        for (uint256 i = 0; i < partnersCollections.length; i++) {
            if (IERC721(partnersCollections[i]).balanceOf(_user) > 0) {
                return true;
            }
        }
        return false;
    }

    function getCollectionsLength() external view returns (uint256) {
        return allCollections.length;
    }
}
