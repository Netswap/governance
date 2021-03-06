const hre = require('hardhat');
const fs = require('fs');

const METIS = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1].address;
    console.log('signer:', signer);

    const TreasuryFactory = await hre.ethers.getContractFactory('CommunityTreasury');
    const NETTFactory = await hre.ethers.getContractFactory('NETT');
    const StakingRewardsFactory = await hre.ethers.getContractFactory('StakingRewards');

    // const NETT = await NETTFactory.deploy();
    // await NETT.deployed();
    const NETT = NETTFactory.attach('0x8127bd4C0e71d5B1f4B28788bb8C4708b51934F9');
    console.log('NETT deployed to: ', NETT.address);

    // const StakingRewards = await StakingRewardsFactory.deploy(
    //     signer,
    //     METIS,
    //     NETT.address
    // );
    // await StakingRewards.deployed();
    const StakingRewards = StakingRewardsFactory.attach('0x99a618756f3BA8304f87c03929A499fB439A1EcF');
    console.log('StakingRewards deployed to: ', StakingRewards.address);

    const Treasury = await TreasuryFactory.deploy(NETT.address);
    await Treasury.deployed();
    console.log('CommunityTreasury deployed to: ', Treasury.address);

    const addresses = {
        NETT: NETT.address,
        StakingRewards: StakingRewards.address,
        CommunityTreasury: Treasury.address,
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