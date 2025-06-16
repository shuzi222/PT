// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@4.9.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";

contract Pteridophyta3 is ERC20, Ownable {
    address public immutable developer;
    uint256 public lastUnlockBlock;
    
    // 解锁配置
    uint256 public constant UNLOCK_INTERVAL = 3600; // 3600 区块 ≈ 3 小时
    uint256 public constant UNLOCK_AMOUNT = 100 * 10**18; // 100 枚代币
    uint256 public constant USER_REWARD_PERCENT = 15; // 0.15% (15/10000)
    uint256 public constant MIN_TRANSFER_AMOUNT = 10 * 10**18; // 最小挖矿转账 10 PT2
    uint256 public constant UNLOCK_FEE = 0.0001 ether; // 尝试手续费 0.0001 BNB
    
    // 状态跟踪
    uint256 public totalUnlocked;
    uint256 public totalUserRewards;
    uint256 public totalBNBFeeCollected;
    
    // 解锁事件
    event TokensUnlocked(
        address indexed trigger, 
        uint256 blockNumber, 
        uint256 totalUnlocked, 
        uint256 userReward,
        uint256 bnbFee
    );
    // 尝试支付事件
    event AttemptFeePaid(
        address indexed payer,
        uint256 bnbFee,
        bool unlockTriggered
    );

    constructor(address _developer) ERC20("Pteridophyta Token3", "PT3") Ownable() {
        require(_developer != address(0), "Invalid developer address");
        developer = _developer; 
        lastUnlockBlock = block.number;
        _mint(_developer, 5_000 * 10**18); // 初始铸造
    }

    // 用户支付 0.0001 BNB 尝试解锁
    function payFeeToUnlock() external payable {
        require(msg.value >= UNLOCK_FEE, "Insufficient BNB fee");

        // 先转移 BNB 给开发者
        uint256 fee = msg.value;
        (bool sent, ) = developer.call{value: fee}("");
        require(sent, "BNB transfer failed");
        totalBNBFeeCollected += fee;

        // 记录尝试支付事件
        bool unlockTriggered = block.number >= lastUnlockBlock + UNLOCK_INTERVAL;
        emit AttemptFeePaid(msg.sender, fee, unlockTriggered);

        // 再检查是否可解锁
        if (unlockTriggered) {
            _checkAndUnlock(msg.sender, fee);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (from == address(0) || to == address(0)) {
            return; // 铸造或销毁不触发解锁
        }
        if (amount < MIN_TRANSFER_AMOUNT) {
            return; // 低于 10 PT2 不触发解锁
        }
        // 通过转账触发解锁
        if (block.number >= lastUnlockBlock + UNLOCK_INTERVAL) {
            _checkAndUnlock(msg.sender, 0);
        }
    }

    function _checkAndUnlock(address trigger, uint256 bnbFee) private {
        uint256 blocksPassed = block.number - lastUnlockBlock;
        if (blocksPassed >= UNLOCK_INTERVAL) {
            uint256 unlockCount = blocksPassed / UNLOCK_INTERVAL;
            uint256 totalUnlock = unlockCount * UNLOCK_AMOUNT;
            
            lastUnlockBlock = block.number;
            uint256 userReward = totalUnlock * USER_REWARD_PERCENT / 10000;
            uint256 developerAmount = totalUnlock - userReward;
            
            _mint(trigger, userReward);
            _mint(developer, developerAmount);
            
            totalUnlocked += totalUnlock;
            totalUserRewards += userReward;
            
            emit TokensUnlocked(trigger, block.number, totalUnlock, userReward, bnbFee);
        }
    }

    function unlockStatus() public view returns (
        uint256 nextUnlockBlock,
        uint256 blocksLeft,
        uint256 timeLeft,
        uint256 nextUnlockAmount,
        uint256 userReward,
        uint256 unlockFee
    ) {
        nextUnlockBlock = lastUnlockBlock + UNLOCK_INTERVAL;
        blocksLeft = block.number >= nextUnlockBlock ? 0 : nextUnlockBlock - block.number;
        timeLeft = blocksLeft * 3; // BSC 平均 3 秒/区块
        nextUnlockAmount = UNLOCK_AMOUNT;
        userReward = UNLOCK_AMOUNT * USER_REWARD_PERCENT / 10000;
        unlockFee = UNLOCK_FEE;
    }

    function globalStats() public view returns (
        uint256 _totalUnlocked,
        uint256 _totalUserRewards,
        uint256 _totalBNBFeeCollected,
        uint256 currentTotalSupply
    ) {
        _totalUnlocked = totalUnlocked;
        _totalUserRewards = totalUserRewards;
        _totalBNBFeeCollected = totalBNBFeeCollected;
        currentTotalSupply = totalSupply();
    }

    // 允许所有者提取合约中的 BNB
    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool sent, ) = msg.sender.call{value: balance}("");
            require(sent, "BNB withdrawal failed");
        }
    }

    // 接收 BNB 的回退函数
    receive() external payable {}
}