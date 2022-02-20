const hre = require('hardhat');
const fs = require('fs');

// Metis
const Metis = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';

//  LP token
// NETT/m.USDC - pid 1
const lpToken1 = '0x0724d37522585e87d27c802728e824862dc72861';
// NETT/m.USDT - pid 0
const lpToken2 = '0x7d02ab940d7dd2b771e59633bbc1ed6ec2b99af1';
// WETH/NETT - pid 3
const lpToken3 = '0xc8ae82a0ab6ada2062b812827e1556c0fa448dd0';

// MINES/Metis - pid 12
const MINESMetis = '0xa22e47e0e60caeaacd19a372ad3d14b9d7279e74';
const perSec = '167824074074074';

// NETT/m.USDC - 100 Metis for 30 days
const tokenPerSec1 = '38580246913580'
// NETT/m.USDT - 100 Metis for 30 days
const tokenPerSec2 = '38580246913580'
// WETH/NETT - 120 Metis for 30 days
const tokenPerSec3 = '46296296296296'

// Mainnet NETTFarm
const NETTFarm = '0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052';

// 2022-02-19 15:00 UTC
// const startTime = 1645282800;
// 2022-02-19 15:30 UTC
const startTime = Math.round(Date.now()/1000) + 5*60

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const SimpleRewarderPerSecFactory = await hre.ethers.getContractFactory('SimpleRewarderPerSec');

    console.log('deploying MINESMetisRewarder...');
    const MINESMetisRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        Metis,
        MINESMetis,
        perSec,
        NETTFarm,
        true,
        startTime
    );
    await MINESMetisRewarder.deployed();
    console.log('MINESMetisRewarder deployed to: ', MINESMetisRewarder.address);

    console.log('deploying NETTUSDCRewarder...');
    const NETTUSDCRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        Metis,
        lpToken1,
        tokenPerSec1,
        NETTFarm,
        true,
        startTime
    );
    await NETTUSDCRewarder.deployed();
    console.log('NETTUSDCRewarder deployed to: ', NETTUSDCRewarder.address);

    console.log('deploying NETTUSDTRewarder...');
    const NETTUSDTRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        Metis,
        lpToken2,
        tokenPerSec2,
        NETTFarm,
        true,
        startTime
    );
    await NETTUSDTRewarder.deployed();
    console.log('NETTUSDTRewarder deployed to: ', NETTUSDTRewarder.address);

    console.log('deploying NETTWETHRewarder...');
    const NETTWETHRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        Metis,
        lpToken3,
        tokenPerSec3,
        NETTFarm,
        true,
        startTime
    );
    await NETTWETHRewarder.deployed();
    console.log('NETTWETHRewarder deployed to: ', NETTWETHRewarder.address);

    const addresses = {
        MINESMetisRewarder: MINESMetisRewarder.address,
        NETTUSDCRewarder: NETTUSDCRewarder.address,
        NETTUSDTRewarder: NETTUSDTRewarder.address,
        NETTWETHRewarder: NETTWETHRewarder.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mainnet-rewarders.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });