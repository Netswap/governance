const hre = require('hardhat');
const fs = require('fs');

const METIS = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const NETTFactory = await hre.ethers.getContractFactory('NETT');
    const StakingRewardsFactory = await hre.ethers.getContractFactory('StakingRewards');

    const NETT = await NETTFactory.deploy();
    await NETT.deployed();
    console.log('NETT deployed to: ', NETT.address);

    const StakingRewards = await StakingRewardsFactory.deploy(
        signer,
        METIS,
        NETT.address
    );
    await StakingRewards.deployed();
    console.log('StakingRewards deployed to: ', StakingRewards.address);

    const addresses = {
        NETT: NETT.address,
        StakingRewards: StakingRewards.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/testnet-addresses.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });