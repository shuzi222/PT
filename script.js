// 合约配置
const CONTRACT_ADDRESS = "0x7D79b855606577a75576fFF9A2c23681ac72f069"; // 合约地址
const CONTRACT_ABI = [
  {
    type: "function",
    name: "payFeeToUnlock",
    inputs: [],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "unlockStatus",
    inputs: [],
    outputs: [
      { name: "nextUnlockBlock", type: "uint256" },
      { name: "blocksLeft", type: "uint256" },
      { name: "timeLeft", type: "uint256" },
      { name: "nextUnlockAmount", type: "uint256" },
      { name: "userReward", type: "uint256" },
      { name: "unlockFee", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "AttemptFeePaid",
    inputs: [
      { indexed: true, name: "payer", type: "address" },
      { name: "bnbFee", type: "uint256" },
      { name: "unlockTriggered", type: "bool" },
    ],
  },
];
const BSC_TESTNET = {
  chainId: "0x61", // 97
  rpcUrls: ["https://data-seed-prebsc-1-s1.binance.org:8545/"],
  chainName: "Binance Smart Chain Testnet",
  nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
  blockExplorerUrls: ["https://testnet.bscscan.com"],
};

// DOM 元素
const connectButton = document.getElementById("connect-wallet");
const payButton = document.getElementById("pay-unlock");
const statusElement = document.getElementById("status");
const blocksLeftElement = document.getElementById("blocks-left");

// 初始化
let provider, signer, contract;

async function init() {
  if (!window.ethereum) {
    updateStatus("看什么看，你TM都没安装 MetaMask ");
    return;
  }
  provider = new ethers.providers.Web3Provider(window.ethereum);
  await checkWallet();
  window.ethereum.on("accountsChanged", checkWallet);
  window.ethereum.on("chainChanged", () => window.location.reload());
}

async function checkWallet() {
  try {
    const accounts = await provider.listAccounts();
    if (accounts.length > 0) {
      signer = provider.getSigner();
      contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const address = await signer.getAddress();
      connectButton.textContent = `${address.slice(0, 6)}...${address.slice(-4)}`;
      payButton.disabled = false;
      updateStatus("钱包已连接！");
      fetchBlocksLeft();
    }
  } catch (error) {
    updateStatus(`错误：${error.message}`);
  }
}

async function connectWallet() {
  try {
    await provider.send("eth_requestAccounts", []);
    await switchNetwork();
    signer = provider.getSigner();
    contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
    const address = await signer.getAddress();
    connectButton.textContent = `${address.slice(0, 6)}...${address.slice(-4)}`;
    payButton.disabled = false;
    updateStatus("钱包已连接！");
    fetchBlocksLeft();
  } catch (error) {
    updateStatus(`连接失败：${error.message}`);
  }
}

async function switchNetwork() {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: BSC_TESTNET.chainId }],
    });
  } catch (error) {
    if (error.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [BSC_TESTNET],
      });
    } else {
      throw error;
    }
  }
}

async function fetchBlocksLeft() {
  try {
    const status = await contract.unlockStatus();
    blocksLeftElement.textContent = `剩余解锁区块：${status.blocksLeft.toString()}（约 ${status.timeLeft.toString()} 秒）`;
  } catch (error) {
    updateStatus(`状态获取失败：${error.message}`);
  }
}

async function payFeeToUnlock() {
  try {
    updateStatus("交易处理中...");
    const tx = await contract.payFeeToUnlock({
      value: ethers.utils.parseEther("0.0001"),
      gasLimit: 500000,
    });
    await tx.wait();
    updateStatus(`交易成功！<a href="https://testnet.bscscan.com/tx/${tx.hash}" target="_blank">查看交易</a>`);
    fetchBlocksLeft();
  } catch (error) {
    updateStatus(`交易失败：${error.message}`);
  }
}

function updateStatus(message) {
  statusElement.innerHTML = `状态：${message}`;
}

// 绑定事件
connectButton.addEventListener("click", connectWallet);
payButton.addEventListener("click", payFeeToUnlock);

// 启动
init();
