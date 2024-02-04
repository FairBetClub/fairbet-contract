import { HardhatUserConfig, task } from 'hardhat/config';
import { formatUnits, formatEther, parseUnits } from 'ethers';
import '@nomicfoundation/hardhat-toolbox';
require('@nomicfoundation/hardhat-verify');
require('hardhat-contract-sizer');
require('@nomicfoundation/hardhat-chai-matchers');
import BigNumber from 'bignumber.js';
function getAccounts(networkName: string) {
  const { parsed } = require('dotenv').config({ path: `.env.${networkName}` });
  let MNEMONIC;
  if (parsed) {
    MNEMONIC = parsed.MNEMONIC.split(',');
  }
  return MNEMONIC;
}
task('accounts', 'Prints the list of accounts', async () => {
  const { ethers } = require('hardhat');
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    let nonce = await ethers.provider.getTransactionCount(account.address, 'pending');
    const balance = await ethers.provider.getBalance(account.address);
    console.log(account.address, BigNumber(formatEther(balance)).toFixed(3) + 'ETH', 'nonce:' + nonce);
  }
});
task('nonce', 'Prints the list of accounts', async () => {
  const { ethers } = require('hardhat');
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    let pending = await ethers.provider.getTransactionCount(account.address, 'pending');
    let latest = await ethers.provider.getTransactionCount(account.address, 'latest');
    console.log(`${account.address} pending:${pending} latest:${latest}`);
  }
});
task('chainId', 'Prints chainId', async () => {
  const { ethers } = require('hardhat');
  const { chainId } = await ethers.provider.getNetwork();
  console.log(chainId + ' hex:0x' + chainId.toString('16'));
});
task('gasPrice', 'Prints gas price of chain', async () => {
  const { ethers } = require('hardhat');
  const FeeData = await ethers.provider.getFeeData();
  console.log({
    gasPrice: formatUnits(FeeData.gasPrice, 'gwei') + ' gwei',
    maxFeePerGas: formatUnits(FeeData.maxFeePerGas, 'gwei') + ' gwei',
    maxPriorityFeePerGas: formatUnits(FeeData.maxPriorityFeePerGas, 'gwei') + ' gwei',
  });
});
task('balance', "Prints an account's balance")
  .addParam('account', "The account's address")
  .setAction(async (taskArgs) => {
    const { ethers } = require('hardhat');
    const balance = await ethers.provider.getBalance(taskArgs.account);
    console.log(formatEther(balance), 'ETH', balance.toString());
  });
task('transfer', 'transfer balance')
  .addParam('from', "The from account's address")
  .addParam('to', "The to account's address")
  .addParam('amount', "The to account's address")
  .setAction(async (taskArgs) => {
    const { ethers } = require('hardhat');
    const from = await ethers.getSigner(taskArgs.from);
    const to = await ethers.getSigner(taskArgs.to);
    const feeData = await ethers.provider.getFeeData();
    let balance = await ethers.provider.getBalance(from.address);
    // Create a transaction object
    let amount = taskArgs.amount;
    let value;
    let gas = await from.estimateGas({
      to: to.address,
      value: BigNumber(balance.toString()).multipliedBy('0.99').toFixed(0),
      // gasPrice: feeData.gasPrice,
    });
    if (amount) {
      value = BigNumber(amount).multipliedBy(1e18).toFixed(0);
    } else {
      let fee = BigNumber(gas.toString()).multipliedBy(feeData.gasPrice.toString()).multipliedBy(1.2).toFixed(0);
      value = BigNumber(balance.toString())
        // .div(2)
        .minus(fee)
        .toFixed(0);
    }
    let tx = {
      to: to.address,
      gasPrice: feeData.gasPrice,
      gasLimit: BigNumber(gas.toString()).multipliedBy(1.2).toFixed(0),
      // Convert currency unit from ether to wei
      value,
      // nonce: 2,
    };
    let resp = await from.sendTransaction(tx);
    await resp.wait();
    console.log(`txHash:${resp.hash} amount:${BigNumber(value).div(1e18).toFixed(6)} `);
  });
task('reset', 'reset network').setAction(async () => {
  const helpers = require('@nomicfoundation/hardhat-toolbox/network-helpers');
  await helpers.reset();
});
const config: HardhatUserConfig = {
  solidity: {
    // version: '0.8.21',
    version: '0.8.18',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        // blockNumber: 29874110,
        // url: 'https://sepolia.gateway.tenderly.co',
        // url: 'https://bsc-testnet.publicnode.com',
        // url: 'https://mainnet.gateway.tenderly.co',
        url: 'https://binance.llamarpc.com',
      },
      // accounts: [
      //     {
      //         privateKey: '',
      //         balance: '10000000000000000000000',
      //     },
      // ],
      // gasPrice: Number(parseUnits('47', 'gwei')),
    },
    sepolia: {
      // url: 'https://sepolia.gateway.tenderly.co',
      url: 'https://eth-sepolia.public.blastapi.io',
      accounts: getAccounts('testing'),
      chainId: 11155111,
      // gasPrice: Number(parseUnits("10", "gwei")),
    },
    bscTest: {
      url: 'https://bsc-testnet.publicnode.com',
      chainId: 97,
      accounts: getAccounts('testing'),
      // gasPrice: Number(parseUnits('12', 'gwei')),
    },
    mainnet: {
      url: 'https://ethereum.blockpi.network/v1/rpc/public',
      chainId: 1,
      accounts: getAccounts('mainnet'),
    },
    bsc: {
      url: 'https://bsc-pokt.nodies.app',
      chainId: 56,
      accounts: getAccounts('mainnet'),
    },
    local: {
      url: 'HTTP://127.0.0.1:7545',
    },
  },
  etherscan: {
    apiKey: {
      mainnet: 'ZED9UBXMWQNR6JJZQM8G59BRVWIB4NDSCV',
      bsc: 'YTBFRXWQ1DRYXI55GC67UHFU1AYW6WTTDT',
    },
  },
};
export default config;
