const hre = require('hardhat');
const fs = require('fs');

// Testnet NETT
// const NETT = '0x8127bd4C0e71d5B1f4B28788bb8C4708b51934F9';
// Mainnet NETT
const NETT = '0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278'

const devAddr = '0x4a642be622EBa7C40eFC06A8f8E1B3278b1fce4E';
const nettPerSec = '941780821917808300'

// Mainnet start time: 2022-01-09 23:00:00
const startTimestamp = '1641740400';
// Testnet start time: 2022-01-04 15:00:00
// const startTimestamp = '1641279600';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const NETTFarmFactory = await hre.ethers.getContractFactory('NETTFarm');

    const NETTFarm = await NETTFarmFactory.connect(signer).deploy(
        NETT,
        devAddr,
        nettPerSec,
        startTimestamp
    );
    await NETTFarm.deployed();
    console.log('NETTFarm deployed to: ', NETTFarm.address);

    const addresses = {
        NETTFarm: NETTFarm.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mainnet-nettfarm-addr.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });