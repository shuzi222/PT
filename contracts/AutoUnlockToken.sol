// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@4.9.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";

contract AutoUnlockToken is ERC20, Ownable {
    address public immutable developer;
    uint256 public lastUnlockBlock;

    // 解锁配置
    uint256 public constant UNLOCK_INTERVAL = 3600; // 3600 区块 ≈ 3 小时
    uint256 public constant UNLOCK_AMOUNT = 100 * 10**18; // 100 枚代币
    uint256 public constant USER_REWARD_PERCENT = 15; // 0.15% (15/10000)

    // 状态跟踪
    uint256 public totalUnlocked;
    uint256 public totalUserRewards;

    // 解锁事件
    event TokensUnlocked(
        address indexed trigger,
        uint256 blockNumber,
        uint256 totalUnlocked,
        uint256 userReward
    );

    constructor(address _developer) ERC20("Pteridophyta Token", "PT") Ownable() {
        require(_developer != address(0), "Invalid developer address");
        developer = _developer;
        lastUnlockBlock = block.number;
        _mint(_developer, 5_000 * 10**18); // 初始铸造给 developer
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (from == address(0) || to == address(0)) {
            return;
        }
        if (block.number >= lastUnlockBlock + UNLOCK_INTERVAL) {
            _checkAndUnlock(msg.sender);
        }
    }

    function _checkAndUnlock(address trigger) private {
        uint256 blocksPassed = block.number - lastUnlockBlock;
        if (blocksPassed >= UNLOCK_INTERVAL) {
            uint256 unlockCount = blocksPassed / UNLOCK_INTERVAL;
            uint256 totalUnlock = unlockCount * UNLOCK_AMOUNT;

            lastUnlockBlock = block.number; // 精确更新
            uint256 userReward = totalUnlock * USER_REWARD_PERCENT / 10000;
            uint256 developerAmount = totalUnlock - userReward;

            _mint(trigger, userReward);
            _mint(developer, developerAmount);

            totalUnlocked += totalUnlock;
            totalUserRewards += userReward;

            emit TokensUnlocked(trigger, block.number, totalUnlock, userReward);
        }
    }

    function unlockStatus() public view returns (
        uint256 nextUnlockBlock,
        uint256 blocksLeft,
        uint256 timeLeft,
        uint256 nextUnlockAmount,
        uint256 userReward
    ) {
        nextUnlockBlock = lastUnlockBlock + UNLOCK_INTERVAL;
        blocksLeft = block.number >= nextUnlockBlock ? 0 : nextUnlockBlock - block.number;
        timeLeft = blocksLeft * 3; // BSC 平均 3 秒/区块
        nextUnlockAmount = UNLOCK_AMOUNT;
        userReward = UNLOCK_AMOUNT * USER_REWARD_PERCENT / 10000;
    }

    function globalStats() public view returns (
        uint256 _totalUnlocked,
        uint256 _totalUserRewards,
        uint256 currentTotalSupply
    ) {
        _totalUnlocked = totalUnlocked;
        _totalUserRewards = totalUserRewards;
        currentTotalSupply = totalSupply();
    }
}