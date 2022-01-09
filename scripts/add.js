const hre = require('hardhat');
const fs = require('fs');

const pools = require('./pools.json');
const nettFarm = require('./mainnet-nettfarm-addr.json');
const NETTFARM_ADDR = nettFarm.NETTFarm;

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const NETTFarmFactory = await hre.ethers.getContractFactory('NETTFarm');

    const NETTFarm = NETTFarmFactory.attach(NETTFARM_ADDR);

    console.log(pools);

    for (let index = 0; index < pools.length; index++) {
        const pool = pools[index];
        console.log(`adding ${pool.name}...`);
        const tx = await NETTFarm.connect(signer).add(
            pool.allocPoint,
            pool.lpToken,
            pool.rewarder
        );
        console.log(tx);
        console.log(`${pool.name} pool added!`);
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });