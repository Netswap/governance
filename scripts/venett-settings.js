const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 599 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const veNETTCF = await hre.ethers.getContractFactory('VeNETT');

    const veNETTObj = require(`../deployments/${chainId === 599 ? 'testnet' : 'mainnet'}/veNETT.json`);
    const veNETTAddr = veNETTObj.veNETT;

    const veNETTStakingObj = require(`../deployments/${chainId === 599 ? 'testnet' : 'mainnet'}/veNETTStakingProxy.json`);
    const veNETTStakingAddr = veNETTStakingObj.veNETTStakingProxy;

    const BoostedNETTFarmObj = require(`../deployments/${chainId === 599 ? 'testnet' : 'mainnet'}/BoostedNETTFarmProxy.json`);
    const BoostedNETTFarmAddr = BoostedNETTFarmObj.BoostedNETTFarmProxy;

    const veNETT = veNETTCF.attach(veNETTAddr);

    // set boostednettfarm address
    await veNETT.setBoostedNETTFarm(BoostedNETTFarmAddr);
    console.log('setBoostedNETTFarm executed');
    // transfer ownership of veNETT to veNETTStaking
    await veNETT.transferOwnership(veNETTStakingAddr);
    console.log('transferOwnership executed');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });