const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const BlackHoleFactory = await hre.ethers.getContractFactory('BlackHole');
    const BlackHole = await BlackHoleFactory.connect(signer).deploy();
    await BlackHole.deployed();
    console.log('BlackHole is deployed to: ', BlackHole.address);


    const addresses = {
        BlackHole: BlackHole.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/BlackHole.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });