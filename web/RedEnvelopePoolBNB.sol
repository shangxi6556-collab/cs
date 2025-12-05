// contracts/RedEnvelopePoolBNB.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RedEnvelopePoolBNB is ReentrancyGuard, Ownable {
    IERC20 public immutable token;
    uint256 public currentRound;
    uint256 public roundStartTime;
    uint256 public remainingBNB;
    uint256 public remainingSlots;

    uint256 public constant MIN_HOLD = 10_000 * 1e18;   // 必须持有 10000 枚
    uint256 public constant MAX_WINNERS = 100;
    uint256 public constant DURATION = 1 hours;

    address[] public winnersThisRound;
    mapping(address => bool) public claimed;

    event NewRound(uint256 round, uint256 bnb, uint256 slots);
    event Claimed(address user, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
        _transferOwnership(msg.sender);
    }

    receive() external payable {}

    // 机器人每小时调用一次（带本轮中奖名单）
    function startNewRound(address[] calldata winners) external onlyOwner {
        require(block.timestamp >= roundStartTime + DURATION || currentRound == 0);
        require(winners.length <= MAX_WINNERS && winners.length > 0);

        remainingBNB = address(this).balance;   // 没抢完自动回流
        currentRound++;
        roundStartTime = block.timestamp;
        remainingSlots = winners.length;

        winnersThisRound = winners;
        delete claimed;

        emit NewRound(currentRound, remainingBNB, remainingSlots);
    }

    // 用户网页手动抢（先抢先得）
    function claim() external nonReentrant {
        require(block.timestamp < roundStartTime + DURATION, "Round ended");
        require(remainingSlots > 0, "No slots");
        require(!claimed[msg.sender], "Already claimed");
        require(token.balanceOf(msg.sender) >= MIN_HOLD, "Hold >= 10,000 tokens");

        // 必须在机器人名单里
        bool ok = false;
        for (uint i = 0; i < winnersThisRound.length; i++) {
            if (winnersThisRound[i] == msg.sender) { ok = true; break; }
        }
        require(ok, "Not winner");

        claimed[msg.sender] = true;
        remainingSlots--;

        uint256 amount = 0.02 ether + (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 998) * 0.01 ether;
        if (amount > remainingBNB) amount = remainingBNB;

        remainingBNB -= amount;
        payable(msg.sender).transfer(amount);

        emit Claimed(msg.sender, amount);
    }
}