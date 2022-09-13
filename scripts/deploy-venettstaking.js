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

    // const veNETTCF = await hre.ethers.getContractFactory('VeNETT');
    const veNETTStakingCF = await hre.ethers.getContractFactory('VeNETTStaking');

    const veNETTObj = require(`../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/veNETT.json`);
    const veNETTAddr = veNETTObj.veNETT;
    const NETTObj = require(`../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/NETT.json`);
    const NETTAddr = NETTObj.NETT;
    const veNETTPerSharePerSec = '3170979198376';
    const speedUpVeNETTPerSharePerSec = '3170979198376';
    const speedUpThreshold = 5;
    const speedUpDuration = 15 * 24 * 60 * 60;
    const maxCapPct = 10000;

    const veNETTStakingProxy = await hre.upgrades.deployProxy(
        veNETTStakingCF, 
        [
            NETTAddr, 
            veNETTAddr,
            veNETTPerSharePerSec,
            speedUpVeNETTPerSharePerSec,
            speedUpThreshold,
            speedUpDuration,
            maxCapPct
        ], 
        {
            initializer: "initialize"
        }
    );
    await veNETTStakingProxy.deployed();
    console.log('veNETTStakingProxy is deployed to: ', veNETTStakingProxy.address);

    const addresses = {
        veNETTStakingProxy: veNETTStakingProxy.address,
    };

    fs.writeFileSync(path.resolve(__dirname, `../deployments/${chainId === 588 ? 'testnet' : 'mainnet'}/veNETTStakingProxy.json`), JSON.stringify(addresses, null, 4));

    // transfer veNETT ownership to veNETTStaking
    // const veNETT = veNETTCF.attach(veNETTAddr);
    // await veNETT.transferOwnership(veNETTStakingProxy.address);
    // console.log('transfer veNETT ownership to veNETTStaking');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });