const hre = require('hardhat');
const fs = require('fs');

// const RELAY = '0xfe282Af5f9eB59C30A3f78789EEfFA704188bdD4';
// const Hera = '0x6F05709bc91Bad933346F9E159f0D3FdBc2c9DCE'
const DXP = '0xa31848aa61f784cdbb6f74260d224a4356295799'
const NETT = '0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const StakingRewardsFactory = await hre.ethers.getContractFactory('StakingRewards');
    const StakingRewards = await StakingRewardsFactory.connect(signer).deploy(
        signer.address,
        DXP,
        NETT
    );
    await StakingRewards.deployed();
    console.log('StakingRewards for DXP deployed to: ', StakingRewards.address);


    const addresses = {
        StakingRewardsDXP: StakingRewards.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/stake-dxp-address.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });