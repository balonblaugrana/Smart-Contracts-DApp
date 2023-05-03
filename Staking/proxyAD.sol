// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./House Staking.sol";
import "./SafeMath.sol";
import "./IERC721Enumerable.sol";
import "./IERC20.sol";
import "./Ownable.sol";

interface IBiscuits is IERC20 {
    function claimable(address user) external view returns (uint256);
}

contract housesStakingProxy is Ownable {
    using SafeMath for uint256;

    // WoofAristoCohabit public ihs =
    //     WoofAristoCohabit(0x89c11CfD72791d272b1Cc22DB19d4ae28D9B4612);
    // IBiscuits public bsc;
    // address public houses = 0x51A1229843d2a594350bA4CD9528f34A2385028e;
    // address public aristoDogs = 0x72aE234e9f01111DEd3550511d71937C39c0CAaf;
    // address public aristoWolves = 0x20171E8A48Cd5A9eeB68d4f273c24aA3Ae3ECD3b;
    // address public leash = 0x8B845d28C39DeE2388a268884c6e6330D7Fbfa56;

    WoofAristoCohabit public ihs =
        WoofAristoCohabit(0x1f356a1E3073e74FBa744A37101B200825F3c123);
    IBiscuits public bsc =
        IBiscuits(0xA5E2B65Aa8C95584699fa6dEb838333e20E24862);
    address public houses = 0x44907Fa1766eFbd607738A6387f46CcFfC62fc23;
    address public aristoDogs = 0x0aecdAf71c1e5c461D2730eEe5243E7b0A81dC7b;
    address public aristoWolves;
    address public leash;

    function setHousesStakingAddress(address _address) external onlyOwner {
        ihs = WoofAristoCohabit(_address);
    }

    function setBiscuitsAddress(address _address) external onlyOwner {
        bsc = IBiscuits(_address);
    }

    function setHousesAddress(address _address) external onlyOwner {
        houses = _address;
    }

    function setDogAddress(address _address) external onlyOwner {
        aristoDogs = _address;
    }

    function setWolvesAddress(address _address) external onlyOwner {
        aristoWolves = _address;
    }

    function setLeashAddress(address _address) external onlyOwner {
        leash = _address;
    }

    function getSpecialInWalletOf(
        address _owner
    ) public view returns (uint256[] memory) {
        if (leash != address(0)) {
            return getWalletOfOwner(_owner, leash);
        } else {
            uint256[] memory empty;
            return empty;
        }
    }

    function _concatenateUint(
        uint256[] memory _Ids1,
        uint256[] memory _Ids2
    ) internal pure returns (uint256[] memory) {
        uint256[] memory _Ids = new uint256[](_Ids1.length + _Ids2.length);
        uint256 i = 0;
        for (; i < _Ids1.length; i++) {
            _Ids[i] = _Ids1[i];
        }
        uint256 j = 0;
        while (j < _Ids2.length) {
            _Ids[i++] = _Ids2[j++];
        }
        return _Ids;
    }

    function getBoosterInWalletOf(
        address _owner
    ) public view returns (uint256[] memory, address[] memory) {
        uint256[] memory dogsIds = getWalletOfOwner(_owner, aristoDogs);
        uint256[] memory wolfIds;
        if (aristoWolves != address(0)) {
            wolfIds = getWalletOfOwner(_owner, aristoWolves);
        }
        uint256[] memory tokenIds = _concatenateUint(dogsIds, wolfIds);
        for (uint256 i; i < ihs.partnersCount(); i++) {
            uint256[] memory _partnerIds = getWalletOfOwner(
                _owner,
                ihs.partners(i)
            );
            tokenIds = _concatenateUint(tokenIds, _partnerIds);
        }

        address[] memory addresses = new address[](tokenIds.length);
        uint256 count;
        for (uint256 i; i < dogsIds.length; i++) {
            addresses[count++] = aristoDogs;
        }
        for (uint256 i; i < wolfIds.length; i++) {
            addresses[count++] = aristoWolves;
        }
        for (uint256 i; i < ihs.partnersCount(); i++) {
            address _p = ihs.partners(i);
            uint256 len = IERC721(_p).balanceOf(_owner);
            for (uint j; j < len; j++) {
                addresses[count++] = _p;
            }
        }
        return (tokenIds, addresses);
    }

    function getWalletOfOwner(
        address _owner,
        address _collection
    ) public view returns (uint256[] memory) {
        IERC721Enumerable nft = IERC721Enumerable(_collection);
        uint256 ownerTokenCount = nft.balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = nft.tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function _getWalletBooster(
        address _address
    ) internal view returns (uint256 count) {
        count += IERC721(aristoDogs).balanceOf(_address);
        if (aristoWolves != address(0)) {
            count += IERC721(aristoWolves).balanceOf(_address);
        }
        for (uint256 i; i < ihs.partnersCount(); i++) {
            count += IERC721(ihs.partners(i)).balanceOf(_address);
        }
    }

    function getUnclaimedPoint(
        address _address
    ) public view returns (uint256 seasonPoints) {
        seasonPoints += ihs
            .viewPointsPerDay(_address)
            .mul(block.timestamp.sub(ihs.timestamps(_address)))
            .div(86400);
    }

    function getUnclaimedStakersPoints(
        uint256 a,
        uint256 b
    ) public view returns (uint256 totalPoints) {
        for (uint256 i = a; i < b; i++) {
            totalPoints += getUnclaimedPoint(ihs.stakersMapping(i));
        }
    }

    function getStakingData(
        address _address
    )
        external
        view
        returns (
            uint256 housesStaked,
            uint256 fullHouses,
            uint256 boostersStaked,
            uint256 specialBoostersStaked,
            uint256 totalHouses,
            uint256 totalBoosters,
            uint256 totalSpecial,
            uint256[4] memory seasonInfo, // season, secPassed, seasonPoints, totalPoints // else: Stack too deep
            uint256 bscBalance,
            uint256 claimableBSC
        )
    {
        housesStaked = ihs.usersHousesCount(_address);
        fullHouses = ihs.getFullHousesCount(_address);
        boostersStaked = ihs.getBoostersCount(_address);

        totalHouses = housesStaked + IERC721(houses).balanceOf(_address);
        totalBoosters = boostersStaked + _getWalletBooster(_address);
        if (address(leash) != address(0)) {
            specialBoostersStaked = ihs.getSpecialCount(_address);
            totalSpecial =
                specialBoostersStaked +
                IERC721(leash).balanceOf(_address);
        } else {
            specialBoostersStaked = 0;
            totalSpecial = 0;
        }
        uint256 season = ihs.season();
        seasonInfo[0] = season;
        seasonInfo[1] = block.timestamp - ihs.seasonStartTime(season);
        seasonInfo[2] =
            ihs.pointsBalance(season, _address) +
            getUnclaimedPoint(_address);
        seasonInfo[3] = ihs.totalPoints(season);
        bscBalance = bsc.balanceOf(_address);
        claimableBSC = bsc.claimable(_address);
    }

    function _getBoosterCountHouses(
        uint256[] memory houseIds
    ) internal view returns (uint256[] memory) {
        uint256[] memory countBooster = new uint256[](houseIds.length);
        for (uint256 i; i < houseIds.length; i++) {
            countBooster[i] = ihs.boosterCount(houseIds[i]);
        }
        return countBooster;
    }

    function _getAreSpecialHouses(
        uint256[] memory houseIds
    ) internal view returns (bool[] memory) {
        bool[] memory countSpecial = new bool[](houseIds.length);
        for (uint256 i; i < houseIds.length; i++) {
            countSpecial[i] = ihs.isSpecial(houseIds[i]);
        }
        return countSpecial;
    }

    function getUserHouses(
        address _address
    )
        external
        view
        returns (
            uint256[] memory staked,
            uint256[] memory notStaked,
            uint256[] memory countBooster,
            bool[] memory countSpecial
        )
    {
        staked = ihs.viewHousesStaked(_address);
        notStaked = getWalletOfOwner(_address, houses);
        countBooster = _getBoosterCountHouses(staked);
        countSpecial = _getAreSpecialHouses(staked);
    }

    function viewStakersCount() external view returns (uint256) {
        return ihs.stakersCount();
    }
}
