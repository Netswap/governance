const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

// Testnet NETT
const NETT = '0xFa68A34EdfBb4Db3716AbC366E5B9390823f69Cf';
// Mainnet NETT
// const NETT = '0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278'

const devAddr = '0x4a642be622EBa7C40eFC06A8f8E1B3278b1fce4E';
const nettPerSec = '52083333333333336'

// Mainnet start time: 2022-01-09 23:00:00
// const startTimestamp = '1641740400';
// Testnet start time: 2022-01-04 15:00:00
// const startTimestamp = '1641279600';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 588 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const NETTFarmFactory = await hre.ethers.getContractFactory('NETTFarm');

    const NETTFarm = await NETTFarmFactory.connect(signer).deploy(
        NETT,
        devAddr,
        nettPerSec,
        Math.round(Date.now() / 1000)
    );
    await NETTFarm.deployed();
    console.log('NETTFarm is deployed to: ', NETTFarm.address);

    const addresses = {
        NETTFarm: NETTFarm.address,
    };

    console.log(addresses);

    fs.writeFileSync(path.resolve(__dirname, `../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/NETTFarm.json`), JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });