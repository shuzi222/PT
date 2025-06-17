// 合约配置
const CONTRACT_ADDRESS = "0x0Ee37377b465ea8B5174550AB9980f81f00364A9";
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

// 代币配置
const TOKEN_ADDRESS = "0x0Ee37377b465ea8B5174550AB9980f81f00364A9"; //代币合约地址
const TOKEN_SYMBOL = "PT";
const TOKEN_DECIMALS = 18;
const TOKEN_IMAGE = "";

// BSC 主网配置
const BSC_MAINNET = {
  chainId: "0x38", // BSC 主网链 ID (56 十进制)
  rpcUrls: ["https://bsc-dataseed.binance.org/"], // 主网官方 RPC
  chainName: "Binance Smart Chain Mainnet",
  nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
  blockExplorerUrls: ["https://bscscan.com"], // 主网 BscScan
};

// DOM 元素
const connectButton = document.getElementById("connect-wallet");
const payButton = document.getElementById("pay-unlock");
const addTokenButton = document.getElementById("add-token");
const statusElement = document.getElementById("status");
const blocksLeftElement = document.getElementById("blocks-left");

// 初始化
let provider, signer, contract;

async function init() {
  console.log("Initializing dApp...");
  if (typeof ethers === "undefined") {
    updateStatus("ethers.js 加载失败，请检查文件或刷新页面！");
    console.error("Ethers.js not loaded!");
    return;
  }
  console.log("Ethers version:", ethers.version);
  if (!ethers.providers) {
    updateStatus("ethers.js 模块错误，请检查 ethers.js 文件！");
    console.error("Ethers providers not found:", ethers);
    return;
  }
  if (!window.ethereum) {
    updateStatus("请安装 <a href='https://metamask.io/download/' target='_blank'>MetaMask</a>！");
    console.error("MetaMask not detected!");
    return;
  }
  console.log("MetaMask detected:", window.ethereum);
  try {
    provider = new ethers.providers.Web3Provider(window.ethereum);
    console.log("Provider initialized:", provider);
    await checkWallet();
    window.ethereum.on("accountsChanged", checkWallet);
    window.ethereum.on("chainChanged", () => window.location.reload());
  } catch (error) {
    console.error("Init error:", error);
    updateStatus(`初始化失败：${error.message}`);
  }
}

async function checkWallet() {
  console.log("Checking wallet...");
  try {
    if (!provider) {
      provider = new ethers.providers.Web3Provider(window.ethereum);
    }
    const accounts = await provider.listAccounts();
    if (accounts.length > 0) {
      signer = provider.getSigner();
      contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const address = await signer.getAddress();
      connectButton.textContent = `${address.slice(0, 6)}...${address.slice(-4)}`;
      payButton.disabled = false;
      addTokenButton.disabled = false;
      updateStatus("钱包已连接！");
      fetchBlocksLeft();
    }
  } catch (error) {
    console.error("Check wallet error:", error);
    updateStatus(`错误：${error.message}`);
  }
}

async function connectWallet() {
  console.log("Connect wallet clicked!");
  try {
    if (!window.ethereum) {
      updateStatus("请安装 <a href='https://metamask.io/download/' target='_blank'>MetaMask</a>！");
      return;
    }
    if (!provider) {
      provider = new ethers.providers.Web3Provider(window.ethereum);
    }
    await provider.send("eth_requestAccounts", []);
    await switchNetwork();
    signer = provider.getSigner();
    contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
    const address = await signer.getAddress();
    connectButton.textContent = `${address.slice(0, 6)}...${address.slice(-4)}`;
    payButton.disabled = false;
    addTokenButton.disabled = false;
    updateStatus("钱包已连接！");
    fetchBlocksLeft();
  } catch (error) {
    console.error("Connect wallet error:", error);
    updateStatus(`连接失败：${error.message}`);
  }
}

async function switchNetwork() {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: BSC_MAINNET.chainId }], // 切换到 BSC 主网
    });
  } catch (error) {
    if (error.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [BSC_MAINNET], // 添加 BSC 主网配置
      });
    } else {
      console.error("Switch network error:", error);
      throw error;
    }
  }
}

async function addToken() {
  console.log("Add token clicked!");
  try {
    if (!window.ethereum) {
      updateStatus("请安装 <a href='https://metamask.io/download/' target='_blank'>MetaMask</a>！");
      return;
    }
    const wasAdded = await window.ethereum.request({
      method: "wallet_watchAsset",
      params: {
        type: "ERC20",
        options: {
          address: TOKEN_ADDRESS,
          symbol: TOKEN_SYMBOL,
          decimals: TOKEN_DECIMALS,
          image: TOKEN_IMAGE,
        },
      },
    });
    if (wasAdded) {
      updateStatus("PT2 代币已添加至 MetaMask！");
    } else {
      updateStatus("用户取消了添加代币！");
    }
  } catch (error) {
    console.error("Add token error:", error);
    updateStatus(`添加代币失败：${error.message}`);
  }
}

async function fetchBlocksLeft() {
  try {
    if (!contract) {
      contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, provider);
    }
    const status = await contract.unlockStatus();
    blocksLeftElement.textContent = `剩余解锁区块：${status.blocksLeft.toString()}（约 ${status.timeLeft.toString()} 秒）`;
  } catch (error) {
    console.error("Fetch blocks error:", error);
    updateStatus(`状态获取失败：${error.message}`);
  }
}

async function payFeeToUnlock() {
  try {
    updateStatus("交易处理中...");
    statusElement.classList.add("loading");
    if (!contract) {
      contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
    }
    const tx = await contract.payFeeToUnlock({
      value: ethers.utils.parseEther("0.0002"),
      gasLimit: 300000,
    });
    await tx.wait();
    statusElement.classList.remove("loading");
    updateStatus(`交易成功！<a href="https://testnet.bscscan.com/tx/${tx.hash}" target="_blank">查看交易</a>`);
    fetchBlocksLeft();
  } catch (error) {
    console.error("Pay fee error:", error);
    statusElement.classList.remove("loading");
    updateStatus(`交易失败：${error.message}`);
  }
}

function updateStatus(message) {
  statusElement.innerHTML = `状态：${message}`;
}

// 绑定事件
if (connectButton) {
  connectButton.addEventListener("click", connectWallet);
} else {
  console.error("Connect button not found!");
}
if (payButton) {
  payButton.addEventListener("click", payFeeToUnlock);
} else {
  console.error("Pay button not found!");
}
if (addTokenButton) {
  addTokenButton.addEventListener("click", addToken);
  addTokenButton.disabled = true; // 初始禁用，连接钱包后启用
} else {
  console.error("Add token button not found!");
}

// 启动
init();
