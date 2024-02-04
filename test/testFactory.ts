import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { Tool } from '../scripts/Tool';
import BigNumber from 'bignumber.js';

const sepoliaConfig = {
  route: '0xD0daae2231E9CB96b94C8512223533293C3693Bf',
  chainId: '16015286601757825753',
  link: '0x779877A7B0D9E8603169DdbD7836e478b4624789',
  weth: '0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534',
};
const bscConfig = {
  route: '0x9527e2d01a3064ef6b50c1da1c0cc523803bcff2',
  chainId: '13264668187771770619',
  link: '0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06',
  wbnb: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
};

const name = 'Wrapped Ethereum';
const symbol = 'WETH';

async function deployFixtureMockBsc() {
  const BridgeFactory = await ethers.getContractFactory('BridgeFactory');
  const bridgeFactory = await BridgeFactory.deploy();
  await bridgeFactory.waitForDeployment();

  const Bridge = await ethers.getContractFactory('Bridge');
  const bridge = await Bridge.deploy(bscConfig.route);
  await bridge.waitForDeployment();
  return { bridgeFactory, bridge };
}

async function deployFixtureMockSepolia() {
  const BridgeFactory = await ethers.getContractFactory('BridgeFactory');
  const bridgeFactory = await BridgeFactory.deploy();
  await bridgeFactory.waitForDeployment();

  const Bridge = await ethers.getContractFactory('Bridge');
  const bridge = await Bridge.deploy(sepoliaConfig.route);
  await bridge.waitForDeployment();
  return { bridgeFactory, bridge };
}

describe('BridgeFactory', async function () {
  it('bsc Test', async function () {
    let tx;
    const ERC20Token = await ethers.getContractFactory('ERC20Token');
    const { bridgeFactory, bridge } = await loadFixture(deployFixtureMockBsc);
    console.log({ bridgeFactory: await bridgeFactory.getAddress() });
    await bridge.setAlowChain(sepoliaConfig.chainId, true);
    let [signer, signer2, signer3] = await ethers.getSigners();
    tx = await bridgeFactory.connect(signer).create1(name, symbol, bridge.getAddress(), BigNumber(1e18).multipliedBy(1e18).toFixed(0));
    let byteCode = await bridgeFactory.keccak256ByteCode(ERC20Token.bytecode);
    const WETH = await bridge.getCreatAddress(signer.address, name, byteCode);
    tx = await bridge['tokenInit(string,bytes32)'](name, byteCode);
    await bridge['setTargetTokenOwner(uint64,address,address)'](sepoliaConfig.chainId, ethers.ZeroAddress, signer.address);
    tx = await bridge.updateTokenTarget(WETH, ethers.ZeroAddress, 18, [sepoliaConfig.chainId]);
    tx = await bridge['tokenInit(string,bytes32)'](name, byteCode);
    await Tool.printReceipt(tx);
    const target = await bridge.targetTokenAddress(sepoliaConfig.chainId, WETH);
    const coder = ethers.AbiCoder.defaultAbiCoder();
    let data = coder.encode(['address', 'address', 'uint256'], [target, signer3.address, BigNumber(1e18).multipliedBy('0.01').toFixed()]);
    tx = await bridge.mint(WETH, signer3.address, BigNumber(1e18).multipliedBy('0.01').toFixed());
    await Tool.printReceipt(tx);
    const weth = await ethers.getContractAt('ERC20Token', WETH);
    tx = await weth.connect(signer3).approve(bridge.getAddress(), BigNumber(1e18).multipliedBy(1).toFixed(0));
    await Tool.printReceipt(tx);

    let data2 = coder.encode(['uint8', 'bytes'], [1, data]);
    let fee = await bridge.calculatedFees(sepoliaConfig.chainId, data2, 200_000);
    console.log(BigNumber(1e18).multipliedBy('0.01').plus(fee.toString()).toFixed());
    tx = await bridge.connect(signer3).moveToChain(sepoliaConfig.chainId, WETH, signer3.address, BigNumber(1e18).multipliedBy('0.01').toFixed(), {
      value: fee.toString(),
    });
    await Tool.printReceipt(tx);
  });

  it('sepolia Test', async function () {
    let tx;
    let [signer, signer2, signer3] = await ethers.getSigners();
    const ERC20Token = await ethers.getContractFactory('ERC20Token');
    const { bridgeFactory, bridge } = await loadFixture(deployFixtureMockSepolia);
    console.log({ bridgeFactory: await bridgeFactory.getAddress() });
    tx = await bridge.setAlowChain(bscConfig.chainId, true);
    await Tool.printReceipt(tx);
    let byteCode = await bridgeFactory.keccak256ByteCode(ERC20Token.bytecode);
    tx = await bridge.connect(signer).setTokenOwner(ethers.ZeroAddress, signer.address);
    await Tool.printReceipt(tx);
    tx = await bridge['setTargetTokenOwner(string,bytes32,uint64[])'](name, byteCode, [bscConfig.chainId]);
    await Tool.printReceipt(tx);
    const WETH = await bridge.getCreatAddress(signer.address, name, byteCode);
    tx = await bridge.updateTokenTarget(ethers.ZeroAddress, WETH, 18, [bscConfig.chainId]);
    await Tool.printReceipt(tx);
    tx = await bridge.tokenBaseInit(ethers.ZeroAddress);
    await Tool.printReceipt(tx);

    const target = await bridge.targetTokenAddress(bscConfig.chainId, ethers.ZeroAddress);
    const coder = ethers.AbiCoder.defaultAbiCoder();
    let data = coder.encode(['address', 'address', 'uint256'], [target, signer3.address, BigNumber(1e18).multipliedBy('0.01').toFixed()]);
    let data2 = coder.encode(['uint8', 'bytes'], [1, data]);
    let fee = await bridge.calculatedFees(bscConfig.chainId, data2, 200_000);
    console.log('------' + BigNumber(1e18).multipliedBy('0.01').plus(fee.toString()).toFixed() + '  fee:' + fee.toString());
    tx = await bridge.connect(signer3).moveToChain(bscConfig.chainId, ethers.ZeroAddress, signer3.address, BigNumber(1e18).multipliedBy('0.01').toFixed(), {
      value: BigNumber(1e18).multipliedBy('0.01').plus(fee.toString()).toFixed(),
    });
    await Tool.printReceipt(tx);
  });
});
