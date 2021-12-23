const hre = require('hardhat');
const fs = require('fs');
const testJson = require('./result-airdrop-phase1.json');
const mainnetAddresses = require('./mainnet-addresses.json');

const merkleRoot = testJson.merkleRoot;
const airdropToken = mainnetAddresses.NETT;
// UTC time: 2022-06-30 15:00:00
const endTime = 1656601200;

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const MerkleDistributorFactory = await hre.ethers.getContractFactory('MerkleDistributor');

    const MerkleDistributor = await MerkleDistributorFactory.connect(signer).deploy(
        airdropToken,
        merkleRoot,
        endTime
    );
    await MerkleDistributor.deployed();
    console.log('MerkleDistributor deployed to: ', MerkleDistributor.address);

    const addresses = {
        MerkleDistributor: MerkleDistributor.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mainnet-merkledistributor-phase1.json`, JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });