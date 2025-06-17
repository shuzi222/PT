// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@4.9.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";

contract Pteridophyta_now is ERC20, Ownable {
    address public immutable developer;
    uint256 public lastUnlockBlock;
    
    // 解锁配置
    uint256 public constant UNLOCK_INTERVAL = 7200; // 7200 区块 ≈ 3 小时
    uint256 public constant UNLOCK_AMOUNT = 100 * 10**18; // 100 枚代币
    uint256 public constant USER_REWARD_PERCENT = 15; // 0.15% (15/10000)
    uint256 public constant MIN_TRANSFER_AMOUNT = 10 * 10**18; // 最小挖矿转账 10 PT
    uint256 public constant UNLOCK_FEE = 0.0002 ether; // 尝试手续费 0.0002 BNB
    
    // 状态跟踪
    uint256 public totalUnlocked;
    uint256 public totalUserRewards;
    uint256 public totalBNBFeeCollected;
    
    // BNB 支付记录
    struct BNBFeePayment {
        address payer;
        uint256 blockNumber;
        uint256 fee;
    }
    BNBFeePayment[] public recentBNBFeePayments;
    uint256 public constant BNB_PAYMENTS_REQUIRED = 3; // 需要 3 笔 BNB 支付触发奖励
    
    // 伪随机数种子
    uint256 private nonce;
    
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
        bool rewardTriggered
    );

    constructor(address _developer) ERC20("Pteridophyta Token", "PT") Ownable() {
        require(_developer != address(0), "Invalid developer address");
        developer = _developer; 
        lastUnlockBlock = block.number;
        _mint(_developer, 5_000 * 10**18); // 初始铸造
    }

    // 伪随机选择函数
    function _randomSelect(uint256 maxIndex) private returns (uint256) {
        if (maxIndex == 0) return 0;
        nonce++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, nonce, msg.sender))) % maxIndex;
    }

    // 用户支付 0.0002 BNB 触发奖励
    function payFeeToUnlock() external payable {
        require(msg.value >= UNLOCK_FEE, "Insufficient BNB fee");

        // 记录 BNB 支付
        recentBNBFeePayments.push(BNBFeePayment({
            payer: msg.sender,
            blockNumber: block.number,
            fee: msg.value
        }));
        totalBNBFeeCollected += msg.value;

        // 转移 BNB 给开发者
        (bool sent, ) = developer.call{value: msg.value}("");
        require(sent, "BNB transfer failed");

        // 检查是否达到 3 笔支付
        bool rewardTriggered = recentBNBFeePayments.length >= BNB_PAYMENTS_REQUIRED;
        emit AttemptFeePaid(msg.sender, msg.value, rewardTriggered);

        // 触发奖励
        if (rewardTriggered) {
            // 随机选择支付者
            uint256 randomIndex = _randomSelect(recentBNBFeePayments.length);
            address randomBNBRecipient = recentBNBFeePayments[randomIndex].payer;

            // 检查是否满足正常解锁周期
            bool isNormalUnlock = block.number >= lastUnlockBlock + UNLOCK_INTERVAL;
            _distributeBNBReward(randomBNBRecipient, msg.value, isNormalUnlock);

            // 清空 BNB 支付记录
            delete recentBNBFeePayments;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (from == address(0) || to == address(0)) {
            return; // 铸造或销毁不触发解锁
        }
        if (amount < MIN_TRANSFER_AMOUNT) {
            return; // 低于 10 PT 不触发解锁
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
            uint256 userReward = totalUnlock * USER_REWARD_PERCENT / 10000; // 0.15%
            uint256 developerAmount = totalUnlock - userReward;
            
            _mint(trigger, userReward);
            _mint(developer, developerAmount);
            
            totalUnlocked += totalUnlock;
            totalUserRewards += userReward;
            
            emit TokensUnlocked(trigger, block.number, totalUnlock, userReward, bnbFee);
        }
    }

    function _distributeBNBReward(address recipient, uint256 bnbFee, bool isNormalUnlock) private {
        uint256 totalUnlock;
        uint256 userReward;
        uint256 developerAmount;

        if (isNormalUnlock) {
            // 正常解锁
            uint256 blocksPassed = block.number - lastUnlockBlock;
            uint256 unlockCount = blocksPassed / UNLOCK_INTERVAL;
            totalUnlock = unlockCount * UNLOCK_AMOUNT;
            lastUnlockBlock = block.number;

            userReward = totalUnlock * USER_REWARD_PERCENT / 10000; // 0.15%
            developerAmount = totalUnlock - userReward;
        } else {
            // 特殊解锁
            totalUnlock = UNLOCK_AMOUNT; // 100 PT
            userReward = totalUnlock * USER_REWARD_PERCENT / 10000; // 0.15%
            developerAmount = totalUnlock - userReward;
        }

        // 铸造奖励
        _mint(recipient, userReward);
        _mint(developer, developerAmount);

        // 更新状态
        totalUnlocked += totalUnlock;
        totalUserRewards += userReward;

        // 发出事件
        emit TokensUnlocked(recipient, block.number, totalUnlock, userReward, bnbFee);
    }

    function unlockStatus() public view returns (
        uint256 nextUnlockBlock,
        uint256 blocksLeft,
        uint256 timeLeft,
        uint256 nextUnlockAmount,
        uint256 userReward,
        uint256 unlockFee,
        uint256 bnbPaymentsLeft
    ) {
        nextUnlockBlock = lastUnlockBlock + UNLOCK_INTERVAL;
        blocksLeft = block.number >= nextUnlockBlock ? 0 : nextUnlockBlock - block.number;
        timeLeft = blocksLeft * 3; // BSC 平均 3 秒一区块
        nextUnlockAmount = UNLOCK_AMOUNT;
        userReward = UNLOCK_AMOUNT * USER_REWARD_PERCENT / 10000; // 0.15%
        unlockFee = UNLOCK_FEE;
        bnbPaymentsLeft = recentBNBFeePayments.length >= BNB_PAYMENTS_REQUIRED ? 0 : BNB_PAYMENTS_REQUIRED - recentBNBFeePayments.length;
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

    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool sent, ) = msg.sender.call{value: balance}("");
            require(sent, "BNB withdrawal failed");
        }
    }

    receive() external payable {}
}