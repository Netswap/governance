const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 59902 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const BoostedNETTFarmCF = await hre.ethers.getContractFactory('BoostedNETTFarm');
    const ERC20MockCF = await hre.ethers.getContractFactory('ERC20Mock');

    const BoostedNETTFarmObj = require(`../deployments/${chainId === 59902 ? 'testnet' : 'mainnet'}/BoostedNETTFarmProxy.json`);
    const BoostedNETTFarmAddr = BoostedNETTFarmObj.BoostedNETTFarmProxy;

    const dummyTokenObj = require(`../deployments/${chainId === 59902 ? 'testnet' : 'mainnet'}/dummyToken.json`)
    const dummyTokenAddr = dummyTokenObj.dummyToken;

    const BoostedNETTFarm = BoostedNETTFarmCF.attach(BoostedNETTFarmAddr);
    const dummyToken = ERC20MockCF.attach(dummyTokenAddr);

    // approve BoostedNETTFarm to use dummyToken
    await dummyToken.approve(BoostedNETTFarmAddr, 1);
    console.log('approve executed');
    // init boostednettfarm
    await BoostedNETTFarm.init(dummyTokenAddr);
    console.log('init executed');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
