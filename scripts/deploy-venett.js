const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 599 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const veNETTCF = await hre.ethers.getContractFactory('VeNETT');

    const veNETT = await veNETTCF.deploy();
    await veNETT.deployed();
    console.log('veNETT is deployed to: ', veNETT.address);

    const addresses = {
        veNETT: veNETT.address,
    };

    fs.writeFileSync(path.resolve(__dirname, `../deployments/${chainId === 599 ? 'testnet' : 'mainnet'}/veNETT.json`), JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });