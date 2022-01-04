const hre = require('hardhat');
const fs = require('fs');

// Testnet rewardToken
// Metis
const rewardToken1 = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';
// TLINK
const rewardToken2 = '0x3Aa437CB25bf718a8952603B24c2ACe332185d95';

// Testnet LP token
// Metis/TUSDC
const lpToken1 = '0xee87eB13DC2b6503F4039c418fd0fc2fedC15594';
// Metis/TLINK
const lpToken2 = '0xE77f2aA9Ba9824170d7C007117461C0d319EF3a9';

// 0.01 per sec
const tokenPerSec = '10000000000000000'

// Testnet NETTFarm
const NETTFarm = '0xd49b1C1030AE2F43010e4FEBf3dC00eAe5E0e4B5';
// Mainnet NETTFarm
// const NETT = ''

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const SimpleRewarderPerSecFactory = await hre.ethers.getContractFactory('SimpleRewarderPerSec');

    const MetisRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        rewardToken1,
        lpToken1,
        tokenPerSec,
        NETTFarm,
        true
    );
    await MetisRewarder.deployed();
    console.log('MetisRewarder deployed to: ', MetisRewarder.address);
    const TLINKRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        rewardToken2,
        lpToken2,
        tokenPerSec,
        NETTFarm,
        false
    );
    await TLINKRewarder.deployed();
    console.log('TLINKRewarder deployed to: ', TLINKRewarder.address);

    const addresses = {
        MetisRewarder: MetisRewarder.address,
        TLINKRewarder: TLINKRewarder.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/testnet-rewarders.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });