const hre = require('hardhat');
const fs = require('fs');

// For test Metis/TUSDC
const LPToken = '0xF6971Ec05557f680b0a8Cd8296C352A115a6e6bd';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 59902 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const BoostedNETTFarmCF = await hre.ethers.getContractFactory('BoostedNETTFarm');

    const BoostedNETTFarmObj = require(`../deployments/${chainId === 59902 ? 'testnet' : 'mainnet'}/BoostedNETTFarmProxy.json`);
    const BoostedNETTFarmAddr = BoostedNETTFarmObj.BoostedNETTFarmProxy;

    const BoostedNETTFarm = BoostedNETTFarmCF.attach(BoostedNETTFarmAddr);

    await BoostedNETTFarm.add(100, 5000, LPToken, '0x0000000000000000000000000000000000000000');
    console.log('add executed');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
