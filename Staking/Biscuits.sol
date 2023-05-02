// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface housesStaking {
    function season() external view returns (uint256 season);

    function totalPoints(
        uint256 season
    ) external view returns (uint256 totalPoints);

    function pointsBalance(
        uint256 season,
        address user
    ) external view returns (uint256 userPoints);
}

contract Biscuits is ERC20, Ownable {
    constructor() ERC20("BISCUIT", "BSC") {}

    using SafeMath for uint256;

    IERC20 public constant WCRO =
        IERC20(0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23);
    housesStaking public hs =
        housesStaking(0x1f356a1E3073e74FBa744A37101B200825F3c123);

    uint256 public rate = 100; // 100 $BSC = 1 $CRO

    // season -> total BSC Claimable
    mapping(uint256 => uint256) totalClaimable;
    mapping(uint256 => uint256) totalClaimed;
    uint256 public totalBurned;

    // season -> user -> !c. / !!c.
    mapping(uint256 => mapping(address => bool)) hasClaimed;

    // gas saving
    uint256 seasonFrom = 1;

    // event
    event Deposit(address who, uint256 amount, uint256 season);

    // setting
    function setHousesStakingAddress(address addr) external onlyOwner {
        hs = housesStaking(addr);
    }

    // max fn

    function depositAllWCRO() external {
        depositWCRO(WCRO.balanceOf(msg.sender));
    }

    function convertAll() external {
        convert(balanceOf(msg.sender));
    }

    // make mintable
    function depositWCRO(uint256 amount) public {
        require(amount > 0, "amount = 0");
        uint256 season = hs.season();
        // approval needed
        WCRO.transferFrom(msg.sender, address(this), amount);
        totalClaimable[season] += amount.mul(rate);
        emit Deposit(msg.sender, amount, season);
    }

    // max mint
    function claimBSC() external {
        uint256 season = hs.season();
        uint256 toClaim;
        for (uint256 i = seasonFrom; i < season; i++) {
            if (!hasClaimed[i][msg.sender]) {
                uint256 amount = totalClaimable[i]
                    .mul(hs.pointsBalance(i, msg.sender))
                    .div(hs.totalPoints(i));
                toClaim += amount;
                totalClaimed[i] += amount;
                hasClaimed[i][msg.sender] = true;
            }
        }
        require(toClaim > 0, "Nothing to claim");
        _mint(msg.sender, toClaim);
    }

    // burn
    function convert(uint256 amountBSC) public {
        require(amountBSC > 0, "amount = 0");
        WCRO.transferFrom(address(this), msg.sender, amountBSC.div(rate));
        totalBurned += amountBSC;
        _burn(msg.sender, amountBSC);
    }

    // View
    function claimable(address user) external view returns (uint256 toClaim) {
        uint256 season = hs.season();
        for (uint256 i = seasonFrom; i < season; i++) {
            if (!hasClaimed[i][user]) {
                toClaim += totalClaimable[i].mul(hs.pointsBalance(i, user)).div(
                        hs.totalPoints(i)
                    );
            }
        }
    }

    // Allows only the last year of seasons to be checked, saving gas in claimBSC.

    function updateSeasonFrom() external onlyOwner {
        uint256 season = hs.season();
        uint256 mounths = 12; // 1 season = 1 mounth
        require(season > mounths);
        uint256 amount;
        for (uint256 i = seasonFrom; i < season.sub(mounths); i++) {
            uint256 delta = totalClaimable[i].sub(totalClaimed[i]);
            if (delta > 0) {
                amount += delta;
                totalClaimed[i] = totalClaimable[i];
            }
        }
        _mint(msg.sender, amount);
        seasonFrom = season - mounths;
    }

    // In case someone mistakenly sends CRC20 != WCRO or CRO to this address

    function withrawalERC20(address _erc20) external onlyOwner {
        require(_erc20 != address(WCRO));
        IERC20 coin = IERC20(_erc20);
        uint256 balance = coin.balanceOf(address(this));
        require(balance > 0, "balance = 0");
        coin.transferFrom(address(this), msg.sender, balance);
    }

    function withdrawCRO() external onlyOwner {
        address payable to = payable(msg.sender);
        uint256 balance = address(this).balance;
        require(balance > 0, "balance = 0");
        to.transfer(balance);
    }
}

// WTA
