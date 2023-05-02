// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface partnerIERC20 is IERC20 {
    function getReward() external;
}

interface partnerIERC721 is IERC721 {
    function stake(uint256 tokenId) external;

    function unstake(uint256 tokenId) external;
}

struct HouseInfo {
    address user;
    uint256[4] tokenIds;
    address[3] addresses;
}

contract WoofAristoCohabit is Ownable {
    using SafeMath for uint256;

    // owner
    bool public isPaused;

    // season parameters
    uint256 public season;
    mapping(uint256 => uint256) public seasonStartTime;
    uint256 public seasonDuration = 2592000; //30 days

    // total value (stats)
    mapping(address => uint256) public totalStaked;
    mapping(uint256 => uint256) public totalPoints;

    // WL collections
    IERC721 public houses = IERC721(0x44907Fa1766eFbd607738A6387f46CcFfC62fc23);
    address public aristoDogs = 0x0aecdAf71c1e5c461D2730eEe5243E7b0A81dC7b;
    address public aristoWolves;
    address public dogLeash;
    uint256 public partnersCount;
    mapping(uint256 => address) public partners;

    // collection address -> tokenId -> address owner
    mapping(address => mapping(uint256 => address)) public ownerNFT;

    //partnerAddress -> houseId_i

    //houseId -> HouseInfo
    mapping(uint256 => HouseInfo) public housesMapping;
    mapping(address => uint256) public usersHousesCount;
    //user -> i < usersHousesCount[user] -> houseId
    mapping(address => mapping(uint256 => uint256)) public usersHouses;

    //stakers trackers
    //mapping(address => bool) public isStaking;
    mapping(uint256 => address) public stakersMapping; //stakerIds->
    mapping(address => uint256) public stakerIds;
    uint256 public stakersCount; //>stakerIds_i

    //partners
    mapping(address => bool) public isStakable;
    mapping(address => mapping(uint256 => uint256)) public stakedTime;
    mapping(address => address) public erc20;
    mapping(address => uint256) public rewardPerDay;

    //stakers info
    mapping(uint256 => mapping(address => uint256)) public pointsBalance;
    mapping(address => uint256) public timestamps;

    event partenerAddes(address partner);
    event partenerRemoved(address partner);
    event HouseStaked(address user, uint256 tokenId);
    event HouseUnstaked(address user, uint256 tokenId);
    event HouseBoosted(uint256 houseId, uint256 slot, address user);
    event HouseDeboosted(uint256 houseId, uint256 slot, address user);
    event specialBooster(uint256 houseId, uint256 tokenId, address user);
    event specialDebooster(uint256 houseId, uint256 tokenId, address user);
    event StartSeason(uint256 newSeasonId, uint256 totalPointsOldSeason);

    constructor() {}

    //onlyOwner

    function setPause(bool _val) external onlyOwner {
        isPaused = _val;
    }

    function updateSeasonLength(uint256 _length) external onlyOwner {
        seasonDuration = _length;
    }

    function setAristoWolves(address _address) external onlyOwner {
        aristoWolves = _address;
    }

    function setDogLeash(address _address) external onlyOwner {
        dogLeash = _address;
    }

    function startSeason() external onlyOwner {
        seasonStartTime[++season] = block.timestamp;
        emit StartSeason(season, 0);
    }

    function add_partner(address _address) external onlyOwner {
        partners[partnersCount++] = _address;
        emit partenerAddes(_address);
    }

    function remove_partner(address _address) external onlyOwner {
        _updateAllBalances();
        uint256 partnerId;
        for (uint256 i = 0; i < partnersCount; i++) {
            if (partners[i] == _address) {
                partnerId = i;
            }
        }
        partners[partnerId] = partners[--partnersCount];
        partners[partnersCount] = address(0);
        emit partenerRemoved(_address);
    }

    function addStakerPartner(
        address _address,
        address _erc20,
        uint256 _rewardPerDay
    ) external onlyOwner {
        isStakable[_address] = true;
        erc20[_address] = _erc20;
        rewardPerDay[_address] = _rewardPerDay;
    }

    function removeStakerPartner(address _address) external onlyOwner {
        require(isStakable[_address]);
        isStakable[_address] = false;
        erc20[_address] = address(0);
        rewardPerDay[_address] = 0;
    }

    // internal

    function _getPoints(address staker) internal view returns (uint256) {
        if (timestamps[staker] > 0) {
            return
                _getPointsPerDay(staker)
                    .mul(block.timestamp.sub(timestamps[staker]))
                    .div(86400);
        } else {
            return 0;
        }
    }

    function _updateBalance(address user) internal {
        _checkSeason();
        uint256 points = _getPoints(user);
        pointsBalance[season][user] += points;
        totalPoints[season] += points;
        timestamps[user] = block.timestamp;
    }

    function _updateAllBalances() internal {
        for (uint256 i; i < stakersCount; i++) {
            address user = stakersMapping[i];
            uint256 points = _getPoints(user);
            pointsBalance[season][user] += points;
            totalPoints[season] += points;
            timestamps[user] = block.timestamp;
        }
    }

    function _checkSeason() internal {
        if (block.timestamp > seasonStartTime[season] + seasonDuration) {
            _updateAllBalances();
            _startSeason();
        }
    }

    function _startSeason() internal {
        _updateAllBalances();
        seasonStartTime[++season] = block.timestamp;
        emit StartSeason(season, totalPoints[season--]);
    }

    function _getPointsPerDay(
        address user
    ) internal view returns (uint256 points) {
        for (uint256 i; i < usersHousesCount[user]; i++) {
            points += _getHousePoints(usersHouses[user][i]);
        }
    }

    function _getTier(uint256 tokenId) internal pure returns (uint256) {
        if (tokenId > 1045 && tokenId < 2778) {
            return 1; //House #1733
        } else if (tokenId < 26 || tokenId > 3058) {
            return 2; //TownHouse #1300
        } else {
            return 3; //Mansion #300
        }
    }

    function _isPartner(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < partnersCount; i++) {
            if (partners[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function _isFree(uint256 houseId) internal view returns (bool) {
        HouseInfo memory house = housesMapping[houseId];
        uint256[4] memory tokenIds = house.tokenIds;
        for (uint256 i; i < 4; i++) {
            if (tokenIds[i] != 0) {
                return false;
            }
        }
        return true;
    }

    function _getHousePoints(
        uint256 houseId
    ) internal view returns (uint256 points) {
        HouseInfo memory house = housesMapping[houseId];
        if (house.user != address(0)) {
            points = 5 * _getTier(houseId);
        } else {
            return 0;
        }
        uint256 hostsCount;
        address[3] memory addresses = house.addresses;
        for (uint256 i; i < 3; i++) {
            if (addresses[i] == aristoDogs) {
                points += 3;
                hostsCount++;
            } else if (addresses[i] == aristoWolves) {
                points += 2;
                hostsCount++;
            } else if (_isPartner(addresses[i])) {
                points += 1;
                hostsCount++;
            }
        }
        if (hostsCount == 3) {
            points += 2;
        }
        if (house.tokenIds[3] != 0) {
            points *= 2;
        }
    }

    function _checkPartner(address _address, uint256 _tokenId) internal {
        if (isStakable[_address]) {
            if (stakedTime[_address][_tokenId] == 0) {
                _stakePartner(_address, _tokenId);
            } else {
                _unstakePartner(_address, _tokenId);
            }
        }
    }

    function _stakePartner(address _address, uint256 _tokenId) internal {
        partnerIERC721 partner = partnerIERC721(_address);
        partner.stake(_tokenId);
        stakedTime[_address][_tokenId] = block.timestamp;
    }

    function _unstakePartner(address _address, uint256 _tokenId) internal {
        partnerIERC721 partner = partnerIERC721(_address);
        partner.unstake(_tokenId);
        uint256 reward = rewardPerDay[_address]
            .mul(block.timestamp.sub(stakedTime[_address][_tokenId]))
            .div(86400);
        stakedTime[_address][_tokenId] = 0;
        partnerIERC20 token = partnerIERC20(erc20[_address]);
        if (reward > token.balanceOf(address(this))) {
            token.getReward();
        }
        if (token.balanceOf(address(this)) > reward) {
            token.transferFrom(address(this), msg.sender, reward);
        }
    }

    //(un)stake & (de)boost
    function stakeHouse(uint256 houseId) public {
        require(!isPaused);
        houses.transferFrom(msg.sender, address(this), houseId);
        _updateBalance(msg.sender);
        HouseInfo storage house = housesMapping[houseId];
        house.user = msg.sender;
        ownerNFT[address(houses)][houseId] = msg.sender;
        totalStaked[address(houses)]++;
        usersHouses[msg.sender][usersHousesCount[msg.sender]++] = houseId;
        emit HouseStaked(msg.sender, houseId);

        if (stakerIds[msg.sender] == 0) {
            stakerIds[msg.sender] = ++stakersCount;
            stakersMapping[stakersCount] = msg.sender;
        }
    }

    function boostHouse(
        uint256 houseId,
        uint256 slot,
        uint256 tokenId,
        address _address
    ) public {
        require(!isPaused);
        require(
            msg.sender == ownerNFT[address(houses)][houseId],
            "Only house owner can boost"
        );
        require(
            _address == aristoDogs ||
                _address == aristoWolves ||
                _address == dogLeash ||
                _isPartner(_address),
            "asset not WLed"
        );
        _updateBalance(msg.sender);
        IERC721 nft = IERC721(_address);
        nft.transferFrom(msg.sender, address(this), tokenId);
        HouseInfo storage house = housesMapping[houseId];
        require(house.tokenIds[slot] == 0);
        house.tokenIds[slot] = tokenId;
        ownerNFT[_address][tokenId] = msg.sender;
        _checkPartner(_address, tokenId);
        totalStaked[_address]++;
        if (slot < 3) {
            house.addresses[slot] = _address;
            emit HouseBoosted(houseId, slot, msg.sender);
        } else {
            require(_address == dogLeash);
            emit specialBooster(houseId, tokenId, msg.sender);
        }
    }

    function _findHouseIndex(uint256 houseId) internal returns (uint256) {
        for (uint256 index; index < usersHousesCount[msg.sender]; index++) {
            if (usersHouses[msg.sender][index] == houseId) {
                return index;
            }
        }
        require(false, "_findHouseIndex: problem");
    }

    function unstakeHouse(uint256 houseId) public {
        require(
            msg.sender == ownerNFT[address(houses)][houseId],
            "Only owner can unstake"
        );
        require(_isFree(houseId), "Unstake boost first");
        _updateBalance(msg.sender);
        HouseInfo storage house = housesMapping[houseId];
        house.user = address(0);
        houses.transferFrom(address(this), msg.sender, houseId);
        ownerNFT[address(houses)][houseId] = address(0);
        totalStaked[address(houses)]--;

        uint256 count = usersHousesCount[msg.sender];
        if (count > 1) {
            usersHouses[msg.sender][_findHouseIndex(houseId)] = usersHouses[
                msg.sender
            ][count - 1];
        } else {
            if (stakersCount > 1) {
                stakersMapping[stakerIds[msg.sender]] = stakersMapping[
                    stakersCount - 1
                ];
                stakersMapping[stakersCount - 1] = address(0);
                stakersCount--;
                stakerIds[msg.sender] = 0;
            }
        }
        usersHouses[msg.sender][count - 1] = 0;
        usersHousesCount[msg.sender]--;
        emit HouseUnstaked(msg.sender, houseId);
    }

    function deboostHouse(uint256 houseId, uint256 slot) public {
        require(!isPaused);
        require(
            msg.sender == ownerNFT[address(houses)][houseId],
            "Only house owner can deboost"
        );
        HouseInfo storage house = housesMapping[houseId];
        uint256 tokenId = house.tokenIds[slot];
        address _address = dogLeash;
        if (slot < 3) {
            _address = house.addresses[slot];
            require(_address != address(0));
        } else {
            require(tokenId != 0);
        }

        _updateBalance(msg.sender);
        _checkPartner(_address, tokenId);
        IERC721 nft = IERC721(_address);
        nft.transferFrom(address(this), msg.sender, tokenId);
        house.tokenIds[slot] = 0;
        ownerNFT[_address][tokenId] = address(0);
        totalStaked[_address]--;
        if (slot < 3) {
            house.addresses[slot] = address(0);
            emit HouseDeboosted(houseId, slot, msg.sender);
        } else {
            emit specialDebooster(houseId, tokenId, msg.sender);
        }
    }

    function fullUnstake(uint256 houseId) public {
        require(
            msg.sender == ownerNFT[address(houses)][houseId],
            "Only owner can unstake"
        );

        HouseInfo storage house = housesMapping[houseId];
        uint256[4] memory tokenIds = house.tokenIds;
        address[3] memory addresses = house.addresses;

        for (uint256 slot; slot < 3; slot++) {
            if (addresses[slot] != address(0)) {
                deboostHouse(houseId, slot);
            }
        }
        if (tokenIds[3] != 0) {
            deboostHouse(houseId, 3);
        }
        unstakeHouse(houseId);
    }

    //batch
    function batchStakeHouse(uint256[] memory houseIds) external {
        for (uint256 i; i < houseIds.length; i++) {
            stakeHouse(houseIds[i]);
        }
    }

    function batchBoostHouse(
        uint256[] memory houseIds,
        uint256[] memory slots,
        uint256[] memory tokenIds,
        address[] memory _addresses
    ) external {
        for (uint256 i; i < houseIds.length; i++) {
            boostHouse(houseIds[i], slots[i], tokenIds[i], _addresses[i]);
        }
    }

    function batchUnstakeHouse(uint256[] memory houseIds) external {
        for (uint256 i; i < houseIds.length; i++) {
            unstakeHouse(houseIds[i]);
        }
    }

    function batchDeboostHouse(
        uint256 houseId,
        uint256[] memory slots
    ) external {
        for (uint256 i; i < slots.length; i++) {
            deboostHouse(houseId, slots[i]);
        }
    }

    function batchFullUnstake(uint256[] memory houseIds) external {
        for (uint256 i; i < houseIds.length; i++) {
            fullUnstake(houseIds[i]);
        }
    }

    // public view

    function boosterCount(uint256 houseId) public view returns (uint256) {
        HouseInfo memory house = housesMapping[houseId];
        uint256 hostsCount;
        address[3] memory addresses = house.addresses;
        for (uint256 i; i < 3; i++) {
            if (addresses[i] == aristoDogs) {
                hostsCount++;
            } else if (addresses[i] == aristoWolves) {
                hostsCount++;
            } else if (_isPartner(addresses[i])) {
                hostsCount++;
            }
        }
        return hostsCount;
    }

    function isSpecial(uint256 houseId) public view returns (bool) {
        HouseInfo memory house = housesMapping[houseId];
        if (house.tokenIds[3] != 0) {
            return true;
        }
        return false;
    }

    function isFull(uint256 houseId) public view returns (bool) {
        if (boosterCount(houseId) == 3) {
            return true;
        }
        return false;
    }

    // external view

    function getFullHousesCount(
        address user
    ) external view returns (uint256 count) {
        for (uint256 i; i < usersHousesCount[user]; i++) {
            if (isFull(usersHouses[user][i])) {
                count += 1;
            }
        }
        return count;
    }

    function getBoostersCount(
        address user
    ) external view returns (uint256 count) {
        for (uint256 i; i < usersHousesCount[user]; i++) {
            count += boosterCount(usersHouses[user][i]);
        }
    }

    function getSpecialCount(
        address user
    ) external view returns (uint256 count) {
        for (uint256 i; i < usersHousesCount[user]; i++) {
            if (isSpecial(usersHouses[user][i])) {
                count += 1;
            }
        }
    }

    function viewPointsPerDay(address user) external view returns (uint256) {
        return _getPointsPerDay(user);
    }

    function viewHousePoints(uint256 houseId) external view returns (uint256) {
        return _getHousePoints(houseId);
    }

    function viewHouse(
        uint256 houseId
    ) external view returns (address, uint256[4] memory, address[3] memory) {
        HouseInfo memory house = housesMapping[houseId];
        return (house.user, house.tokenIds, house.addresses);
    }

    function viewAssetUserHolding(
        address user,
        address collection
    ) external view returns (uint256[] memory) {
        uint256 counter;
        for (uint256 i; i < usersHousesCount[user]; i++) {
            HouseInfo memory house = housesMapping[usersHouses[user][i]];
            address[3] memory addresses = house.addresses;
            for (uint256 j; j < 4; j++) {
                if (addresses[j] == collection) {
                    counter++;
                }
            }
        }
        uint256[] memory _ids = new uint256[](counter);
        counter = 0;
        for (uint256 i; i < usersHousesCount[user]; i++) {
            HouseInfo memory house = housesMapping[usersHouses[user][i]];
            address[3] memory addresses = house.addresses;
            uint256[4] memory tokenIds = house.tokenIds;
            for (uint256 j; j < 3; j++) {
                if (addresses[j] == collection) {
                    _ids[counter++] = tokenIds[j];
                }
            }
        }
        return _ids;
    }

    function viewHousesStaked(
        address user
    ) external view returns (uint256[] memory) {
        uint256 how = usersHousesCount[user];
        uint256[] memory _ids = new uint256[](how);
        for (uint256 i; i < how; i++) {
            _ids[i] = usersHouses[user][i];
        }
        return _ids;
    }

    function emergencyWithrawalERC721(
        address _erc721,
        address _to,
        uint256 _id
    ) external onlyOwner {
        IERC721(_erc721).transferFrom(address(this), _to, _id);
    }

    function emergencyWithrawalERC20(address _erc20) external onlyOwner {
        IERC20 coin = IERC20(_erc20);
        coin.transferFrom(
            address(this),
            msg.sender,
            coin.balanceOf(address(this))
        );
    }
}
