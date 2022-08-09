const hre = require('hardhat');
const fs = require('fs');
const rewarders = require('./mainnet-rewarders.json');

// Metis
const Metis = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';


// BYTE/m.USDC - pid 16
// const BYTEUSDC = '0x3ab6be89ed5a0d4fdd412c246f5e6ddd250dd45c'
// const MetisPerSec = '231481481481481'


// const Hera = '0x6f05709bc91bad933346f9e159f0d3fdbc2c9dce'
// // Hera/m.USDC - pid 17
// const HERAUSDC = '0x948f9614628d761f86b672f134fc273076c4d623'
// const HeraPerSec = '3858024691358024'

// const DXP = '0xa31848aa61f784cdbb6f74260d224a4356295799'
// // DXP/m.USDC - pid 18
// const DXPUSDC = '0x7cbb5925c65e05933da6aa5c08e49bf464ae3ed8'
// const DXPPerSec = '15432098765432096'

// HUM/Metis - pid 19
const HUMMetis = '0x838ba1eeb49a2d8a362f3f50cad4a8284045d9c1'
const MetisPerSec = '231481481481481'


// //  LP token
// // NETT/m.USDC - pid 1
// const lpToken1 = '0x0724d37522585e87d27c802728e824862dc72861';
// // NETT/m.USDT - pid 0
// const lpToken2 = '0x7d02ab940d7dd2b771e59633bbc1ed6ec2b99af1';
// // WETH/NETT - pid 3
// const lpToken3 = '0xc8ae82a0ab6ada2062b812827e1556c0fa448dd0';

// // MINES/Metis - pid 12
// const MINESMetis = '0xa22e47e0e60caeaacd19a372ad3d14b9d7279e74';
// const perSec = '167824074074074';

// // NETT/m.USDC - 100 Metis for 30 days
// const tokenPerSec1 = '38580246913580'
// // NETT/m.USDT - 100 Metis for 30 days
// const tokenPerSec2 = '38580246913580'
// // WETH/NETT - 120 Metis for 30 days
// const tokenPerSec3 = '46296296296296'

// Mainnet NETTFarm
const NETTFarm = '0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052';

// 2022-04-19 15:00 UTC
const startTime = 1650380400

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const SimpleRewarderPerSecFactory = await hre.ethers.getContractFactory('SimpleRewarderPerSec');

    console.log('deploying HUMMetisRewarder...');
    const HUMMetisRewarder = await SimpleRewarderPerSecFactory.connect(signer).deploy(
        Metis,
        HUMMetis,
        MetisPerSec,
        NETTFarm,
        false,
        startTime
    );
    await HUMMetisRewarder.deployed();
    console.log('HUMMetisRewarder deployed to: ', HUMMetisRewarder.address);

    rewarders.HUMMetisRewarder = HUMMetisRewarder.address;
    fs.writeFileSync(`${__dirname}/mainnet-rewarders.json`, JSON.stringify(rewarders, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });