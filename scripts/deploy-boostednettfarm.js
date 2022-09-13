const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 588 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const BoostedNETTFarmCF = await hre.ethers.getContractFactory('BoostedNETTFarm');

    const veNETTObj = require(`../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/veNETT.json`);
    const veNETTAddr = veNETTObj.veNETT;
    const NETTObj = require(`../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/NETT.json`);
    const NETTAddr = NETTObj.NETT;
    const NETTFarmObj = require(`../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/NETTFarm.json`)
    const NETTFarmAddr = NETTFarmObj.NETTFarm;
    // TODO
    const MASTER_PID = chainId === 588 ? 0 : 20;

    const BoostedNETTFarmProxy = await hre.upgrades.deployProxy(
        BoostedNETTFarmCF,
        [
            NETTFarmAddr,
            NETTAddr,
            veNETTAddr,
            MASTER_PID
        ],
        {
            initializer: "initialize"
        }
    );
    await BoostedNETTFarmProxy.deployed();
    console.log('BoostedNETTFarmProxy is deployed to: ', BoostedNETTFarmProxy.address);

    const addresses = {
        BoostedNETTFarmProxy: BoostedNETTFarmProxy.address,
    };

    fs.writeFileSync(path.resolve(__dirname, `../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/BoostedNETTFarmProxy.json`), JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });